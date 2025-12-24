# Homelab ansible+terraform on Y.Cloud

Production-like Kubernetes кластер в **Yandex Cloud**, разворачиваемый с использованием **Terraform** и **Ansible**, с дальнейшим управлением платформенными компонентами через **ArgoCD (GitOps)**.

После завершения и стабилизации большинства задач в локальном кластере было принято решение вынести его в облачную среду. Основная цель — практика и углубление навыков **Infrastructure as Code** с использованием Terraform, Ansible на базе Yandex Cloud.

Данный репозиторий описывает архитектуру, принципы и порядок работы платформы без излишних абстракций.

---

## Область покрытия проекта

Проект закрывает полный цикл построения Kubernetes-платформы:

- инфраструктура (IaaS)
- bootstrap Kubernetes
- сеть, балансировка и DNS
- monitoring и logging
- GitOps-управление кластером

---

## Архитектура (high level)

### Terraform

Terraform отвечает за создание и описание инфраструктуры в Yandex Cloud:

- VPC и Subnet
- Compute instances (Master + Workers)
- Network Load Balancer
- DNS
- IAM и Object Storage
- Ansible inventory (auto-generated)

Особое внимание уделю **автогенерации Ansible inventory**.  
IP-адреса виртуальных машин не извлекаются вручную из консоли или UI Yandex Cloud.  
Terraform с помощью `local_file` автоматически формирует inventory-файл и размещает его в нужной директории. После этого достаточно запустить Ansible playbook без дополнительной подготовки, что очень сильно упрощает работу с этими инструментами, а также файл никогда не будет некорректным.

```
Terraform
  ├── VPC / Subnet
  ├── Compute instances (Master + Workers)
  ├── Network Load Balancer
  ├── DNS
  ├── IAM + Object Storage
  └── Ansible inventory (auto-generated)
        ↓
Ansible
        ↓
ArgoCD (GitOps)
```

---

### Ansible

Ansible используется исключительно для установки и супер базоовой настройки Kubernetes-кластера:

- установка Docker и containerd
- установка Kubernetes (kubeadm)
- настройка CNI
- настройка метрик Control Plane
- создание Secrets (YC / CSI)
- установка и начальная настройка ArgoCD

---

### ArgoCD (GitOps)

После bootstrap вся дальнейшая жизнь кластера управляется через GitOps:

- cert-manager
- ingress-nginx
- kube-prometheus-stack
- logging (OpenSearch + Fluent)
- StorageClasses
- другие платформенные компоненты

---

## Terraform: что создаётся и зачем

### Compute instances (VM)

- 1 master node
- N worker nodes (количество задаётся через `var.workers`)
- Public NAT для initial bootstrap
- SSH-ключи передаются через metadata

Масштабирование worker-нод осуществляется изменением одной переменной Terraform.

---

### Сеть (VPC)

- отдельная VPC
- подсеть `10.5.0.0/24`
- все узлы размещены в одной подсети без ненужной(в моём проекте) сегментации

Используемые ресурсы:
- `yandex_vpc_network`
- `yandex_vpc_subnet`

---

### Network Load Balancer (L4)

Network Load Balancer используется как входная точка в Kubernetes-кластер.

| LB Port | Target Port | Назначение              |
|------|------------|-------------------------|
| 80   | 30080      | ingress-nginx HTTP      |
| 443  | 30443      | ingress-nginx HTTPS     |

Используемые ресурсы:
- `yandex_lb_network_load_balancer`
- `yandex_lb_target_group`

Ingress-контроллер работает через **NodePort**, что упрощает архитектуру и подключение нашего LB.

---

### Security Groups

Разрешён следующий трафик:

- Load Balancer → Nodes (30080 / 30443)
- Internet → Load Balancer (80 / 443)

Для NodePort применяются жёсткие ограничения по источникам.

Используемый ресурс:
- `yandex_vpc_security_group`

---

### DNS

- публичная DNS-зона
- A-запись указывает на IP Network Load Balancer
- поддержка нескольких поддоменов

Домен зарегистрирован у стороннего провайдера, выбран бесплатный план(поэтому домена не пугаемся), NS-записи указывают на Yandex Cloud.

Используемые ресурсы:
- `yandex_dns_zone`
- `yandex_dns_recordset`

---

### IAM и Object Storage

Создаётся Service Account для Kubernetes:

- доступ к Object Storage (`storage.editor`)
- static access keys
- bucket для snapshot’ов OpenSearch

Object Storage используется **исключительно для snapshot’ов**, а не для PVC.  
В текущей реализации PVC создаются на базе бакета, это не круто, но протестировать было интересно, сейчас рассматриваю альтернативные SC

Используемые ресурсы:
- `yandex_iam_service_account`
- `yandex_storage_bucket`
- `yandex_storage_bucket_grant`

---

## Ansible: bootstrap Kubernetes

### Этапы выполнения

- Docker + containerd
- Kubernetes packages
- Disable swap и sysctl
- containerd configuration
- kubeadm init
- workers join
- CNI (Weave)
- Control Plane metrics
- Secrets и CSI credentials
- ArgoCD bootstrap

---

Стоит также подчеркнут, что выбран идемпотентный подход, что значит, сколько плейбук не запускай, все будет нормис)

### CSI / Object Storage Secret

Ansible:

- читает ключи из `/tmp/yc-csi.json`
- создаёт Kubernetes Secret
- Secret используется StorageClass’ами

---

## ArgoCD (GitOps)

### Важно

Applications ArgoCD создаются **сразу после установки ArgoCD**.  
Это является ключевой концепцией моего проекта.

Примеры:

```bash
kubectl apply -f cert-manager/Application.yaml
kubectl apply -f ingress/Application.yaml
kubectl apply -f kube-prometheus-stack/Application.yaml
```

---

### Что управляется через ArgoCD

- cert-manager
- ingress-nginx
- kube-prometheus-stack
- OpenSearch
- OpenSearch Dashboards
- Fluent
- StorageClasses
- GitLab Runner
- KEDA
- Let`s Encrypt Issuer

После завершения начальной установки Ansible больше не используется

---

## Безопасность

- SSH-доступ только по ключам
- TLS в ingress
- RBAC для Control Plane
- IAM Service Accounts
- Secrets не хранятся в Terraform state

---

## Итог

После выполнения Terraform и Ansible:

- осуществляется вход в ArgoCD
- подключается Git-репозиторий
- ожидается автоматический sync

В результате кластер полностью развёрнут, все инструменты установлены и доступны по HTTPS с сертификатами Let’s Encrypt.  
Обычно для таких инструментов используется отдельный балансер внутри сети без публичного доступа. Здесь я реализовал это в целях демонстрации своих навыков в этой теме.

