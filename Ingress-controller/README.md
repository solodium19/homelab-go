# Ingress Controller + MetalLB Setup Guide

##  Ingress-Controller

Лучшим и самым простым способом развернуть Ingress Controller является использование **Helm chart**. Следуем шагам ниже.

---

##  Добавляем репозиторий и обновляем его

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

---

##  Устанавливаем Ingress Controller

```bash
helm install nginx-ingress ingress-nginx/ingress-nginx   --namespace ingress-nginx   --create-namespace
```

---

##  Создаём правило для маршрутизации (ingress-rules.yaml)

```bash
kubectl create -f ingress-rules-*.yaml # Манифесты переложены в ingress-controller/*
```

---

##  ВАЖНО! Почему это так просто не заработает?

По умолчанию **Ingress Controller не имеет внешнего IP**, а значит сервис типа `LoadBalancer` не сможет получить адрес.  

### Решение — установить **MetalLB**

---

##  Установка MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
```

---

##  Создаем манифесты для MetalLB (AddressPool + L2Advertisement)

Создаем папку:

```
/metallb-manifests/
```

Там размещаем ваши манифесты, затем применяем:

```bash
kubectl create -f /metallb-manifests/.
```

---

##  Проверяем, что сервис Ingress получил IP

```bash
kubectl get svc -n ingress-nginx
```

Вы увидите два сервиса.  
Нас интересует тот, который имеет тип **LoadBalancer** — он должен получить IP из пула, который вы задали.

---

##  Настраиваем hosts

Теперь нужно сказать вашей ОС, что доменные имена указывают на IP, выданный сервису Ingress Controller.

### Linux — файл `/etc/hosts`

```
10.10.31.81 grafana.local.test
10.10.31.81 prom.local.test
10.10.31.81 alert.local.test
```

### Windows — файл:

```
C:/Windows/System32/drivers/etc/hosts
```

Добавляем те же записи.

---

## 🌐 Проверяем в браузере

Переходим по адресу:

```
http://grafana.local.test
```

По умолчанию логин:

```
admin
```

Пароль берём из секрета:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o=jsonpath='{.data.admin-password}' | base64 -d
```

---

##  Готово!

Ingress работает → MetalLB раздаёт IP → доступ к Grafana/Prometheus/Alertmanager по доменным именам!
