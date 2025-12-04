## CI Pipelines

Вот тут и началось самое интересное, мы хотим настроить CI(Continuous Integration) - непрерывную интеграцию, то есть автоматизировать нашу сборку приложений, изменение манифестов и в будущем CD(Continuous Delivery) - непрерывную доставку в нашем случае в кластер

## Планы в голове и реализация этих планов

# Начнем с CI develop
Когда я начинал в этом разбираться казалось, что добиться реализации моих мыслей невозможно, но посмотрим как реализация получилась в нашем репо.
Что мы хотели:
Разработчик пишет код в ветке девелоп, в конкретной папке, например Vote, он изменил какую-то часть кода и запушил его в наш репо, после этого запускается CI, который смотрит на изменение определнной папки и собирает образ на основе её, пушит в репо и меняет этот образ в оверлее кастомайза Develop. На словах отлично и реализация в целом получилась хорошая.
Важно! Наш CI не пересобирает образы всех указанных приложений(vote,result,worker), а собирает лишь только то, что изменилось, если будет 3 изменения в разных директориях то да, он соберёт 3, если 2, то 2, ну смысл мы поняли

Однако, это все работало отлично, пока мы не пошли дальше, теперь мы хотим создавать Мерджы в ветку stage, чтобы наш код переносился develop-stage и конечно же все реализовывалось уже в ветке stage. Я и подумал, так будут перезаписываться файла Ci, так не пойдет, поэтому лучшим решением было вынести CI файлы в отдельную ветку и обращаться к ним по Include, упростит управление этими файлами, та и легко что-то изменить/добавить и лишь указать обращаться в include

# CI Stage
Очень долго я думал об этом, бэд практисом является пересборка новых образов уже в ветке stage, нам нужно использовать тещенные образы уже из ветки develop(+ресурсы +красота), но как это реализовать? По коммитам собирать, ладно если все образы собранны одним коммитом, а если они собраны в разный промежуток времени под разным комитом, сложно будет написать логику для этого, поэтому сделаем намного проще, почитав об этом, я понял, что это довольно гуд практис в хороших компаниях. И реализованно будет это так:

При мерже в ветку стейдж запускается CI, который берет образы с оверлея develop и засовывает их в файл в оверлее stage, ну а дальше уже все в ажуре, вытащены хорошие тещенные образы, argoCD их сам развернёт в кластере, ну и мы в шоколаде. Просто сидим и следим за этим)

Чтобы сложилось впечатление о знании, а не просто копипасте откуда-то разберём наш CI например Develop:

```bash
stages: # Указываем какие стадии у нас будут в нашем пайплайне, стадия можно разбрасывать между джобами как угодно
  - build
  - update-manifests

.build_template: &build_template # Т.К у нас 3 разных сборки, напишем "Шаблон", чтобы каждый раз это не переписывать
  stage: build # Указываем стадию
  tags: [test] # Указываем Тэг-раннера, который будет выполнять этот Job, мы говорили об этом в Infrastructure/gitlab-runner
  image:
    name: gcr.io/kaniko-project/executor:v1.23.0-debug
    entrypoint: [""]
   # Артефакты - это результат выполнения джоба, то есть мы в него записываем какую-то информацию и передаем между джобами, чтобы передать что-то необходимое для работы
  artifacts: 
    reports:
      dotenv: build.env


build_vote:
  <<: *build_template
  # Правило запуска Job`а, он будет запускаться только если в папке /vote были изменения, в противном случае никогда
  rules: 
  - changes:
      - vote/**/*
    when: on_success
  - when: never
  script:
    # Тут как раз таки мы вносим необходимые значения в артефакт, который потом передадим в нужный нам Job
    - echo "SERVICE=vote" >> build.env
    - echo "IMAGE_TAG=$CI_COMMIT_SHA" >> build.env
    - echo "IMAGE_REPO=$CI_REGISTRY_IMAGE/vote" >> build.env

    - > # Много времени здесь не будет тратить, обычная сборка и пуш образа с помощью kaniko(Быстрее, безопаснее, Меньше возни)
      /kaniko/executor 
      --context "$CI_PROJECT_DIR/vote"
      --dockerfile "$CI_PROJECT_DIR/vote/Dockerfile"
      --destination "$CI_REGISTRY_IMAGE/vote:$CI_COMMIT_SHA"
      --destination "$CI_REGISTRY_IMAGE/vote:latest"
      --cache=true
      --cache-repo "$CI_REGISTRY_IMAGE/cache"

# Этот Job копия build_vote, только меняются значения приложения, теперь мы собираем не Vote, а Result, также будет и для воркер, мы его пропустим
build_result:
  <<: *build_template
  rules:
    - changes:
        - result/**/*
    - when: never
  script:
    - echo "SERVICE=result" >> build.env
    - echo "IMAGE_TAG=$CI_COMMIT_SHA" >> build.env
    - echo "IMAGE_REPO=$CI_REGISTRY_IMAGE/result" >> build.env

    - >
      /kaniko/executor
      --context "$CI_PROJECT_DIR/result"
      --dockerfile "$CI_PROJECT_DIR/result/Dockerfile"
      --destination "$CI_REGISTRY_IMAGE/result:$CI_COMMIT_SHA"
      --destination "$CI_REGISTRY_IMAGE/result:latest"
      --cache=true
      --cache-repo "$CI_REGISTRY_IMAGE/cache"


build_worker:
  <<: *build_template
  rules:
    - changes:
        - worker/**/*
    - when: never
  script:
    - echo "SERVICE=worker" >> build.env
    - echo "IMAGE_TAG=$CI_COMMIT_SHA" >> build.env
    - echo "IMAGE_REPO=$CI_REGISTRY_IMAGE/worker" >> build.env

    - >
      /kaniko/executor
      --context "$CI_PROJECT_DIR/worker"
      --dockerfile "$CI_PROJECT_DIR/worker/Dockerfile"
      --destination "$CI_REGISTRY_IMAGE/worker:$CI_COMMIT_SHA"
      --destination "$CI_REGISTRY_IMAGE/worker:latest"
      --cache=true
      --cache-repo "$CI_REGISTRY_IMAGE/cache"

## Создание образов на этом закончилось и переходим к изменению образов в нашей ветке k8s-manifests по пути /k8s/overlays/develop - т.к это ПП для ветки develop
.update_template: &update_template
  stage: update-manifests 
  tags: [test]
  image: alpine:latest
  # Это будет выполнено до выполнения главного скрипта, тут мы просто качаем гит, кастомайз и указываем свои данные для коммита
  before_script: 
    - apk add --no-cache git curl bash
    - curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
    - mv kustomize /usr/local/bin/
    - git config --global user.email "ci@gitlab.com"
    - git config --global user.name "GitLab CI"
# Сам скрипт. Клонируем наш репо, переходим в папку, меняем образ, коммитим и вауля. Наш новый собранный образ уже в манифесте, а если уже в манифесте, то значит уже в кластере :)
   script:
    - git clone --branch k8s-manifests "https://oauth2:${GITLAB_TOKEN}@gitlab.com/solodium191/homelab-go.git" manifests
    - cd manifests/k8s/overlays/develop
    - kustomize edit set image "${IMAGE_REPO}=${IMAGE_REPO}:${IMAGE_TAG}"
    - git add .
    - git commit -m "Update image for ${SERVICE} to ${IMAGE_TAG}" || echo "Nothing to commit"
    - git push origin k8s-manifests

# Ну здесь мы получается выполняем тот скрипт для изменения образа в репо для каждого сервиса, говорим что нам нужен артефакт(тот самый что мы собирали, в нем хранится как раз таки значения какой образ и с каким тэгом мы будем ставить), ну и правило выполнения -> запускать только при изменении определенной папки)
update_vote:
  <<: *update_template
  needs:
    - job: build_vote
      artifacts: true
  rules:
    - changes:
        - vote/**/*
    - when: never

update_result:
  <<: *update_template
  needs:
    - job: build_result
      artifacts: true
  rules:
    - changes:
        - result/**/*
    - when: never

update_worker:
  <<: *update_template
  needs:
    - job: build_worker
      artifacts: true
  rules:
    - changes:
        - worker/**/*
    - when: never

```