## Homelab Kubernetes Platform (Production‑like)

Этот репозиторий содержит мою полностью развёрнутую production-like Kubernetes платформу.
Изначально платформа была построена на bare-metal кластере из 3 нод, однако в рамках развития проекта инфраструктура была перенесена в Yandex Cloud с использованием подхода Infrastructure as Code (Terraform + Ansible).

Здесь собрана инфраструктура, CI/CD, GitOps, мониторинг, логирование, TLS, ingress-слой, Helm-чарты и окружения dev/stage/prod.

Проект создан как полноценная тренировка инженерных навыков DevOps — максимально приближенный к реальным продовым процессам.

---

##  Общая архитектура

Платформа состоит из следующих основных компонентов:

* **Kubernetes cluster (3 nodes, bare-metal)**
* **GitLab CI/CD**: сборка Docker‑образов через Kaniko, пуш в registry, обновление манифестов
* **ArgoCD (GitOps)**: автосинк dev/stage/prod окружений
* **Helm‑чарты (написаны с нуля)**: deployment, statefulset, PVC, secrets, service, ingress
* **Kustomize**: разделение окружений (dev/stage/prod) с overlay'ями
* **Ingress NGINX + TLS (cert‑manager)**
* **Monitoring stack**: kube‑prometheus‑stack, Grafana, Alertmanager
* **Logging**: FluentBit → OpenSearch → OpenSearch Dashboards
* **IaC** : Ansible+Terraform

Пайплайн выглядит так:

```
Git Push → GitLab CI → Kaniko build/push → Update manifests → ArgoCD sync → Deploy to cluster
```

---

##  Структура репозитория

```
homelab-go/
├── main/                     # Основная логика репозитория
│   ├── k8s-manifests/
│   │   ├── charts/           # Helm-чарты, написанные с нуля
│   │   ├── k8s/              # Kustomize (overlays/base)
│   │   └── manifests/        # Ручные манифесты (системные ресурсы, шаблоны)
│   │
│   ├── infra/                        # Инфраструктурные компоненты
│   │   ├── keda/                     # HPA на основе Keda
│   │   ├── ingress-controller/       # ingress-nginx, правила, конфигурации
│   │   ├── kube-prometheus-stack/    # Мониторинг на kube-prometheus-stack
│   │   ├── argoCD/                   # GitOps конфигурации
│   │   |── logging-with-opensearch/  # Логирование
|   |   |── gitlab-runner/            # Self-Hoster runner gitlab
|   |   |── cert-manager/             # Автоматизированная система сертификации
|   |   └── homelab-ansible-terraform/ # Автоматизация развертывания и настройки кластера
│
├── develop/                  # Полноценное dev-окружение
├── stage/                    # stage-окружение
│
├── CI-Pipelines/
│   └── .gitlab-ci/           # GitLab CI конфигурации (Kaniko, deploy, jobs)
│
└── README.md
```

---

##  CI/CD

### GitLab CI

* Self‑hosted GitLab Runner
* Kaniko для сборки образов
* Пуш через GitLab Registry Token
* Автообновление YAML‑манифестов (Kustomize)
* Сборка отдельных сервисов по изменению директорий

### Deployment flow

1. Разработчик пушит изменения в ветку приложения
2. GitLab CI собирает Docker‑образ
3. Данный образ сканируется на уязвимости
3. Образ пушится в registry, если он прошёл успешно скан, отчёт о скане сохраняется артефактом на GitLab
4. GitLab обновляет теги в манифестах dev/stage/prod в Helm Values/Kustomize overlays
5. ArgoCD autodsync деплоит нужные окружения
---

##  GitOps (ArgoCD)

ArgoCD автоматически управляет всем состоянием кластера.

Особенности:

* Полный GitOps для всех окружений
* Auto‑sync включен
* Health checks
* Rollout policy
* Автоматическая доставка новых версий

---

##  Helm‑чарты

Писались полностью вручную.

Реализовано:

* Deployment / StatefulSet
* ConfigMap / Secret
* PVC / PV
* Resources / labels ( Планируется добавить Readiness,Health probes)
* Полная параметризация Values.yaml для отдельных огружений

---

##  Мониторинг и алертинг

Используется:

* kube‑prometheus‑stack
* Grafana (дашборды)
* Prometheus Rules
* Alertmanager

Доступны:

* метрики кластера
* метрики приложений
* алерты по CPU/Memory/Pod Health в Telegram

---

##  Логирование

* FluentBit как DaemonSet
* Отправка логов в OpenSearch
* Визуализация в OpenSearch Dashboards

Покрываются:

* Pod logs
* сервисные логи приложений
* системные логи

---

##  Безопасность

В проекте реализовано:

* cert‑manager на своем сертификационном центре(нет необходимости в отдельном домене)
* TLS для ingress
* Kubernetes Secrets + зашифрованные секреты в Git
---

## Infrastructure as Code (Terraform + Ansible)

Для управления инфраструктурой и автоматизации развёртывания используется связка Terraform + Ansible на базе Yandex Cloud.

Terraform:
- создаёт облачную инфраструктуру в Yandex Cloud
- поднимает VPC, Subnet, DNS, Bucket, ServiceAcc и 3 Compute Instance (1 master, 2 worker)
- вся конфигурация описана декларативно (main.tf, variables.tf, terraform.tfvars)

Ansible:
- устанавливает container runtime (containerd / Docker)
- инициализирует Kubernetes через kubeadm
- подключает worker-ноды
- устанавливает CNI
- добавляются необходимые изменения в кластер для дальнейшей работы ArgoCD
- разворачивает ArgoCD и GitOps Application

Полный lifecycle развёртывания:

Terraform → Cloud Infrastructure  
Ansible → Kubernetes + ArgoCD  
Git → Single Source of Truth

---

##  Окружения

Используются три независимых окружения:

* `dev/` — для разработки
* `stage/` — предпрод/тесты
* `prod/` — стабильная версия

Разделение выполнено через Kustomize overlays, а также написан чарт на Helm 

---

## 🤝 Контакты

Если есть вопросы — обращайтесь:

* Telegram: **@solodium19**

Проект активно развивается — буду рад фидбеку и предложениям для новых реализаций.




