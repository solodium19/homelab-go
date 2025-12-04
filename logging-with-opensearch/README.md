# Opensearch logging

##  Opensearch+fluentbit+opensearchDashboards

Настраиваем логирование в нашем кластере

---

##  Добавляем репозиторий и обновляем его

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts
helm repo update
```

---

##  Устанавливаем opensearch

```bash
helm install opensearch opensearch/opensearch \
  --namespace logging \
  --create-namespace \
  -f opensearch.yaml
```

---

##  Устанавливаем fluentbit

```bash
helm install fluent-bit opensearch/fluent-bit \
  --namespace logging \
  -f fluent-with-lua-newv4-latest.yaml
```

---

## Устанавливаем opensearch-dashboards

```bash
helm install opensearch-dashboards opensearch/opensearch-dashboards \
  --namespace logging \
  -f opensearch-dashboards.yaml
```


---

##  Теперь у нас есть полностью рабочая система мониторинга. Немного о ней

## Наше логирование построено по следующей цепочке, fluent-bit настроен на каждой ноде в виде DaemonSet, он собирает логи и парсит их с в opensearch с индексами host-logs* и kube-logs*, а также у него настроен скрипт lua, который автоматически ставит "log-level", ибо кубернетес в логах не ставит сам уровень логов

## Соберём пару дашбордов в opensearch-dashboards.У нас уже есть ingress controller для этого дела, поэтому лишних настроен нам не придётся делать. Мы идём в браузер по адресу и собираем дашборды там

```bash
https://opensearch.local.test
```

## 
