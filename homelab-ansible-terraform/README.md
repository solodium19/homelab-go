# Infrastructure as Code (Terraform + Ansible)

##  Зачем это вообще нужно

Изначально проект разворачивался на **bare metal**, но со временем стало очевидно:

* сложно масштабироваться;
* нет воспроизводимости окружения;
* много ручных действий;

Поэтому было принято **осознанное решение** — переехать в **Yandex Cloud** и полностью описать инфраструктуру и кластер через **Infrastructure as Code**:

* **Terraform** — отвечает за облачную инфраструктуру
* **Ansible** — за первоначальную настройку и bootstrap Kubernetes

---

##  Архитектура

```
Yandex Cloud
│
├── VPC Network
│   └── Subnet
│
├── 3 Compute Instances
│   ├── master-1 (control plane)
│   ├── worker-1
│   └── worker-2
│
└── Kubernetes Cluster
    ├── containerd
    ├── kubeadm
    ├── CNI
    ├── ArgoCD
    └── Applications (GitOps)
```

---

##  Terraform

Terraform отвечает **только за облако**.

### Что создаётся:

* VPC Network
* Subnet
* 3 VM-инстанса в Yandex Cloud

### Структура Terraform

```
homelab-ansible-terraform/terraform/
├── main.tf              # Основные ресурсы (network, subnet, instances)
├── providers.tf         # Провайдер Yandex Cloud
├── variables.tf         # Переменные
├── terraform.tfvars     # Значения переменных
```

### Как работает

1. Terraform инициализирует провайдер Yandex Cloud
2. Создаёт сеть и подсеть
3. Поднимает 3 VM
4. Возвращает IP-адреса, которые дальше используются Ansible с помощью провайдера local_file, который создаёт уже готовый инвентори файл в ansible

### Запуск Terraform

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

После `apply` у вас есть **готовые VM** — чистые, но уже доступные по SSH.

---

##  Ansible

### Что делает Ansible:

* Установка Docker / containerd
* Настройка kernel / sysctl
* Установка CNI
* Инициализация Kubernetes через `kubeadm`
* Присоединение worker-нод
* Установка ArgoCD
* Деплой ArgoCD Application (GitOps)

Мой плейбук **идемпотентен** — можно запускать сколько угодно раз. Вносятся только необходимые изменения.

---

##  GitOps и ArgoCD

После того как кластер поднят:

* Устанавливается **ArgoCD**
* Создаётся `Application`
* Все Kubernetes-манифесты и Helm-чарты подтягиваются из Git

 **Кластер = отражение репозитория**.
Никакого `kubectl apply -f руками`.

---

##  Почему это правильный подход

✔ Полная воспроизводимость
✔ Быстрый recovery
✔ Масштабируемость
✔ Минимум ручных действий
✔ Git — единственный источник истины

---

##  Как поднять всё с нуля

```bash
# 1. Поднять инфраструктуру
cd homelab-ansible-terraform/terraform
terraform unit/apply

# 2. Настроить кластер
cd ../ansible
ansible-playbook ansible-playbook.yaml -i inventory --ask-vault-pass
```

Через несколько минут у нас:

* 3 VM в Yandex Cloud
* Kubernetes
* ArgoCD
* Задеплоенные приложения и необходимые инструменты

---

##  Итог

Проект был осознанно переведён:

**bare metal → cloud → IaC → GitOps**

P.S Сейчас проект находится на доработке, есть незначительные баги и разбор как по умному передать файлы values в argoCD используя открытые чарты, а также настройка балансировщика в облаке в связке с ingress-controller.

