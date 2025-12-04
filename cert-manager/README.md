# Cert-Manager

##  Cert-manager Download

У нас появилась необходимость в сертификации наших http соединений. Поэтому обратимся к этому мужчинке. Он позволит нам автоматически выпускать сертификаты для любых наших поддоменом и доменов.

---

##  Добавляем репозиторий и обновляем его

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

---

##  Устанавливаем менеджер сертификации

```bash
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
```

---

##  Создаём наш главный CA сертификат и ключик и помещаем его в секретик в K8s

```bash
openssl genrsa -out ca.key 2048

openssl req -x509 -new -nodes -key ca.key -subj "/CN=homelab-CA" -days 3650 -out ca.crt

kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key -n cert-manager
```

---

## Дальше мы говорим, что это наш CA ключ с помощью манифеста ClusterIssuerSelf-signed.yml и ваулая.


---

##  Теперь для того чтобы создать новые сертификаты нам необходимо просто в контролеере Nginx указать в анотации к кому обращаться за этими сертификатами и сказать, что теперь мы используем TLS

```bash
annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
    - hosts:
        - grafana.local.test
      secretName: grafana-tls
```
---

## В нашей локальной сети кластер недоступен из внешней сети, да и покупка домена в нашем случае не нужна, поэтому мы обойдемся следующим решением: Добавим CA.crt как корневой сертификационный центр на нашу пользовательскую машину и сертификат начнет действовать

##  Проверяем в браузере

Переходим по адресу:

```
https://grafana.local.test
```

## Готово!
## Мы видим, что теперь наше соединение теперь защищено. Проделаем теперь это для всех наших подоменнов
