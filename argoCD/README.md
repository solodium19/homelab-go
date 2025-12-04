# ArgoCD AutoDeploy

Настраиваем автоматический деплой(CD) в наш кластер с помощью argoCD, этот инструмент был выбран как самый быстрый, умный и незамороченный в настройке для нашего приложения.

---

##  Создаем новое пространство имён и устанавливаем туда манифест и сразу же разворачиваем его. Он полностью развернет свое окружение в нашем неймспейсе argoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

##  Для успешной настройки перейдём в вебку и подключим наш гитлаб туда, пока без ингресс контроллера, поэтому развернём порты. Пароль достанем jsonpath

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

```

---

##  Далее создадим правило для наших неймспейсов, покажу здесь на примере с неймспейсом develop, куда будут собираться приложения из кастоймайза оверлея девелоп. С остальными окружениями(stage,prod) сделаем также с указанием их директорий.

```bash
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vote-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://gitlab.com/solodium191/homelab-go.git'
    targetRevision: main
    path: k8s/overlays/develop
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: develop
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Итоги:
Все, теперь этот Application можно также посмотреть в вебке, ждать автоматическую синхронизацию или же синхронизировать руками наш репозиторий с нашим кластером. ArgoCD считает, что наш репо - единственная правда, и если манифесты в репо не совпадают с теми что в кластере, он их пересоберёт и автоматически задеплоит.

