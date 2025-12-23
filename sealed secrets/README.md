# Sealed secrets - это способ хранить наши секретики из кубернетеса в Git в зашифрованном виде и расшифровать его сможет только наш кластер
Установка:

kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.33.1/controller.yaml

curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.33.1/kubeseal-0.33.1-linux-amd64.tar.gz"
tar -xvzf kubeseal-0.33.1-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

Создаем секретик локально в кластере файлом например secret.yaml:
apiVersion: v1
data:
  .dockerconfigjson: eyJhdXRocyI6eyJyZWdpc3RyeS5naXRsYWIuY29tIjp7InVzZXJuYW1lIjoiZGVwbG95LXRva2VuIiwicGFzc3dvcmQiOiJnbGR0LWNRemttWno0NlhUdXdGMVF5N1ZxIiwiZW1haWwiOiJyZWdpc3RyeS1kZXBsb3lAZXhhbXBsZS5jb20iLCJhdXRoIjoiWkdWd2JHOTVMWFJ2YTJWdU9tZHNaSFF0WTFGNmEyMWFlalEyV0ZSMWQwWXhVWGszVm5FPSJ9fX0=
kind: Secret
metadata:
  creationTimestamp: null
  name: gitlab-regcred
  namespace: stage
type: kubernetes.io/dockerconfigjson

Я создал его с помощью:
kubectl create secret docker-registry gitlab-regcred   --docker-server=registry.gitlab.com   --docker-username=deploy-token   --docker-password=gldt-cQzkmZz46XTuwF1Qy7Vq   --docker-email=registry-deploy@example.com  -n develop --dry-run=client -o yaml

И теперь загружаем наш манифест в наш helm templates и сможем этот секретик хранить в нашем репозитории в защищенном виде