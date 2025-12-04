# Установка мониторинга кластера с помощью kube-prometheus-stack

## 1. Создаём неймспейс для мониторинга
```
kubectl create namespace monitoring
```

## 2. Устанавливаем хелм репозиторий в наш кластер:
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

## 3. Обновляем репозитории
```
helm repo update
```

---

## Чуть подробнее об нашем values.yaml

В процессе развертывания столкнулись с такой проблемой, что метрики в kubeadm с главных сервисов (etcd, scheduler, controller-manager) собираются только на localhost и обязательно на https (кроме etcd, там все оказалось проще, но решил не отступать от своих убеждений). Мной было принято решение о развертывании мониторинга этих сервисов с помощью создания отдельных скрапов в прометеусе, и разворачивание самого прометеуса на контролплейн ноде, в моем кластере не много ресурсов на разворачивании отдельного прокси, поэтому это посчиталось лучшим решением. Для полной работоспособности нам понадобились сертификаты:

---

## Создание сертификатов на подключение

### Создаем сертификаты для kube-scheduler и kube-controller-manager:

---

### Controller-manager:
/etc/kubernetes/pki/cm-metrics-csr.conf
```
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = v3_req
distinguished_name = dn

[ dn ]
CN = system:kube-controller-manager

[ v3_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
```

```
cd /etc/kubernetes/pki
```

```
openssl genrsa -out cm-metrics.key 2048
```

```
openssl req -new -key cm-metrics.key   -out cm-metrics.csr   -config cm-metrics-csr.conf
```

```
openssl x509 -req   -in cm-metrics.csr   -CA ca.crt -CAkey ca.key -CAcreateserial   -out cm-metrics.crt   -days 365   -extensions v3_req   -extfile cm-metrics-csr.conf
```

---

### Scheduler:

/etc/kubernetes/pki/scheduler-metrics-csr.conf
```
[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = v3_req
distinguished_name = dn

[ dn ]
CN = system:kube-scheduler

[ v3_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
```

```
openssl genrsa -out scheduler-metrics.key 2048
```

```
openssl req -new -key scheduler-metrics.key   -out scheduler-metrics.csr   -config scheduler-metrics-csr.conf
```

```
openssl x509 -req   -in scheduler-metrics.csr   -CA ca.crt -CAkey ca.key -CAcreateserial   -out scheduler-metrics.crt   -days 365   -extensions v3_req   -extfile scheduler-metrics-csr.conf
```

---

## Создаем секрет с нашими сертификатами, этот секрет уже подтянут в values.yaml
```
kubectl -n monitoring create secret generic kube-controlplane-metrics-certs   --from-file=ca.crt=/etc/kubernetes/pki/ca.crt   --from-file=cm.crt=/etc/kubernetes/pki/cm-metrics.crt   --from-file=cm.key=/etc/kubernetes/pki/cm-metrics.key   --from-file=scheduler.crt=/etc/kubernetes/pki/scheduler-metrics.crt   --from-file=scheduler.key=/etc/kubernetes/pki/scheduler-metrics.key
```

## Проверить это подключение можно вот так:
```
printf 'GET /metrics HTTP/1.1
Host: 127.0.0.1
Connection: close

' |   openssl s_client -connect 127.0.0.1:10257     -cert /etc/kubernetes/pki/cm-metrics.crt -key /etc/kubernetes/pki/cm-metrics.key     -CAfile /etc/kubernetes/pki/ca.crt -quiet -ign_eof
```

## Если все сделали правильно, то он скажет нам погулять сходить, ибо нету прав, поэтому создаём кластер роли и привязки и пробуем ещё раз

---

## Далее создаем RBAC:

### controller-manager-metrics-rbac.yaml
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: allow-cm-metrics
rules:
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: allow-cm-metrics
subjects:
  - kind: User
    name: system:kube-controller-manager
roleRef:
  kind: ClusterRole
  name: allow-cm-metrics
  apiGroup: rbac.authorization.k8s.io
```

### scheduler-metrics.rbac.yaml
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: allow-scheduler-metrics
rules:
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: allow-scheduler-metrics
subjects:
  - kind: User
    name: system:kube-scheduler
roleRef:
  kind: ClusterRole
  name: allow-scheduler-metrics
  apiGroup: rbac.authorization.k8s.io
```

---

## Также до установки хелм, я решил, что наш конфиг для скрапа мы поместим в secret, чтобы не хардкодить это в values.yaml

### Создание secret:
```
kubectl create secret generic prometheus-additional-scrape-configs --from-file=secret.yaml=/home/vladislav/secret.yaml --namespace=monitoring
```

---

### Где, secret.yaml:
```
      - job_name: kube-controller-manager
        scheme: https
        static_configs:
          - targets: ["127.0.0.1:10257"]
        tls_config:
          ca_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/ca.crt
          cert_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/cm.crt
          key_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/cm.key
          insecure_skip_verify: true

      - job_name: kube-scheduler
        scheme: https
        static_configs:
          - targets: ["127.0.0.1:10259"]
        tls_config:
          ca_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/ca.crt
          cert_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/scheduler.crt
          key_file: /etc/prometheus/secrets/kube-controlplane-metrics-certs/scheduler.key
          insecure_skip_verify: true

      - job_name: kube-etcd
        scheme: http
        static_configs:
          - targets: ["127.0.0.1:2381"]

      - job_name: kube-proxy
        scheme: http
        static_configs:
          - targets: ["127.0.0.1:10249"]
```

---

## 4. Устанавливаем helm репозиторий с нашим братком values.yaml
```
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```

## 5. Теперь мониторинг в нашем кластере работает, метрики собираются в прометеус, выводятся в графану и настроен алертинг в наш телеграм

Если мы решили что у нас такой крутой мониторинг и алертинг, то надо и соответствующе получать туда доступ и мы пошли дальше с созданием Ingress-controller.

---

## Примеры алёртов которые приходят в телеграм

(Сами правила настраиваются в кластере, получить их можно: `kubectl get prometheusrules -n monitoring`)  
Их достаточно много из коробки, но можно создать и кастомные.

---

### ⚠️ WARNING ALERT
```
⚠️ Pod is crash looping.
📝 Description: Pod monitoring/safe-metrics-proxy-dhdvv (nginx-proxy) is in waiting state (reason: "CrashLoopBackOff") on cluster .

🏷 Labels:
• alertname=KubePodCrashLooping
• container=nginx-proxy
• endpoint=http
• instance=10.36.0.4:8080
• job=kube-state-metrics
• namespace=monitoring
• pod=safe-metrics-proxy-dhdvv
• prometheus=monitoring/kube-prometheus-stack-prometheus
• reason=CrashLoopBackOff
• service=kube-prometheus-stack-kube-state-metrics
• severity=warning
• uid=0365d150-befc-4243-84f0-4d94ef313959
```

---

### 🚨 CRITICAL ALERT 🚨
```
🔥 The API server is burning too much error budget.

📛 Description: The API server is burning too much error budget on cluster .
🧩 Cluster: unknown
📦 Namespace: unknown
⚙️ Service: unknown

🏷 Labels:
• alertname=KubeAPIErrorBudgetBurn
• long=6h
• prometheus=monitoring/kube-prometheus-stack-prometheus
• severity=critical
• short=30m
```
