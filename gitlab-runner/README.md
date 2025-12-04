## GitLabRunner

Начинаем сборку наших пайплайнов, и чтобы они могли где-то выполняться, мы разместим его в нашем кластере и выделим ему отдельную ноду даже для этого(Это было сделано, но позже убрано, т.к ресурсов в моём кластере слишком ограниченное количество, а добавить ещё одну ноду в последствии стало невозможным, но сам механизм реализации моей идее показан), это удобство в том плане, что все наши пайплайны будут выполняться на отдельно выделенном поде, а если быть точнее, то каждый Job, не требующего больших привелегий(как докер например), отрабатывает и успешно удаляется. + Вайб + Ресурсы + Нервы


## Обеспечение безопаности процессов сборки

Для обеспечения изоляции build-процессов была выделена отдельная нода в кластере:

на эту ноду назначен taint, чтобы обычные рабочие нагрузки туда не размещались, только наши раннеры

```bash
kubectl taint node node02-git ci=true:NoSchedule

```

Runner получает toleration и может запускать поды на этой ноде, в отдельном неймспесе, я создал несколько раннеров, чтобы процесс сборки был пошустрее, да и каждый ранер имел свои привелегии(В данном моменте реализация остановилась, т.к большого кол-ва ПП не было, и такое кол-во раннеров не пригодилось, но как демонстрация подойдет)


## Установка GitLab Runner через Helm

```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install gitlab-runner gitlab/gitlab-runner -n gitlab-runner --create-namespace -f values.yaml
```

Где мой, values.yaml был:

```bash
rbac:
 enable: true
 rules:
 - resources: ["pods"]
   verbs: ["create","delete","get", "list", "watch"]
 - apiGroups: [""]
   resources: ["pods/attach","pods/exec"]
   verbs: ["get","create","patch","delete"]
 - apiGroups: [""]
   resources: ["pods/log"]
   verbs: ["get","list"]
 - resources: ["secrets"]
   verbs: ["create","get"]
runners:
  image: "alpine:latest"
serviceAccount:
  create: true
  name: gitlab-runner-build
gitlabUrl: "https://gitlab.com/"
runnerToken: glrt-_3dca7iGMF2K6Jb1tDs8lG86MQpwOjE5cGprNAp0OjMKdTpqMWM0aRg.01.1j0ub3t1x
namespace: ci-cd
nodeSelector:
 kubernetes.io/hostname: node02-git
tolerations:
 - key: "ci"
   operator: "Equal"
   effect: "NoSchedule"
   value: "true"
```
P.S Маленькие поправочки, нод селектор в нашем случае был выбран специально, чтобы не заострять на этом большого внимания и не прописывать Pod/NodeAffinity/AntiAffinity , т.к моё окружение было воссоздано только наполовину(в силу опять же недостатки ресурсов в кластере)
В продуктовой среде лучше использовать Pod/NodeAffinity/AntiAffinity

## Настройки на GitLab

При конфигурации GitLabRunner необходимо указать метку, по которой на него можно будет направить job. Реализация там простая, просто указываем в job нашу метку. В моём случае метка была test. Подробнее про это в описании PipeLine`s