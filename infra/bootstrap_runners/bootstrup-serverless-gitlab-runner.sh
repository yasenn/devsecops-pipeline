# Serverless GitLab Runner для Yandex Cloud Serverless Containers

Идеи и заготовка скрипта: https://git@git.sourcecraft.dev/yandex-cloud-examples/serverless-gitlab-runner.git

# Обертка, предназначенная для запуска в Yandex Cloud Serverless Containers. Сервис принимает GitLab Job Hook вебхуки и по событию запускает одноразовый [GitLab Runner](https://docs.gitlab.com/runner/) командой [`gitlab-runner run-single`](https://docs.gitlab.com/runner/commands/#run-single) с Docker executor внутри контейнера. Это позволяет поднимать раннер только под конкретную сборку и тут же его останавливать. Событие вебхука — GitLab [Job Hook (Job events)](https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#job-events).

### env

set -o allexport
source .env
set +o allexport


yc serverless container create --name serverless-gitlab-runner 
```bash
echo yc lockbox secret create --name gitlab-runner-token --payload '[{"key": "gitlab_runner_token", "text_value": "'$RUNNER_TOKEN'"}]'
yc lockbox secret create --name gitlab-runner-token --payload '[{"key": "gitlab_runner_token", "text_value": "glrt-JAwhX7PYz5Mb9QAfetMLMWc6MXRrCm86MQp0OjIKdTpkNhI.01.1b00nato4"}]'
```
Нам потребуется два сервисных аккаунта:
- Один с доступом к секрету lockbox
- Другой, от имени которого GitLab будет вызывать контейнер
```bash
# Создаём сервисные аккаунты
yc iam service-account create --name gitlab-runner-lockbox-payload-viewer
yc iam service-account create --name gitlab-runner-caller
yc iam service-account list
yc iam service-account get --name gitlab-runner-lockbox-payload-viewer --format=json | jq -r .id
yc iam service-account get --name gitlab-runner-caller --format=json | jq -r .id
```

# права для SA
```bash

folder_id() { yc config get folder-id }
echo $(folder_id)

yc lockbox secret add-access-binding \
  --name gitlab-runner-token \
  --role lockbox.payloadViewer \
  --service-account-name gitlab-runner-lockbox-payload-viewer

yc resource-manager folder add-access-binding \
  --id $(folder_id) \
  --role serverless-containers.containerInvoker \
  --service-account-name gitlab-runner-caller

```

# Api-Key для GitLab Webhooks 
```bash
yc iam api-key create \
  --service-account-name gitlab-runner-caller \
  --scopes yc.serverless.containers.invoke
```

yc iam api-key list --service-account-name gitlab-runner-caller 

# ревизия контейнера
```bash

gitlab_runner_lockbox_payload_viewer_service_account_id() {yc iam service-account get --name gitlab-runner-lockbox-payload-viewer --format=json | jq -r .id}
gitlab_runner_caller_service_account_id() { yc iam service-account get --name gitlab-runner-caller --format=json | jq -r .id }
lockbox_secret_id(){yc lockbox secret get --name gitlab-runner-token --format=json | jq -r .id}
 yc lockbox secret list-versions --help
 lockbox_secret_version_id(){ yc lockbox secret list-versions --name gitlab-runner-token --format=json | jq -r '.[]|select(.status="ACTIVE").id' }
 
yc serverless container revision deploy \
  --container-name serverless-gitlab-runner \
  --image cr.yandex/yc/serverless/gitlab-runner \
  --execution-timeout 600s \
  --runtime=http \
  --memory 1GB \
  --cores 1 \
  --service-account-id $( gitlab_runner_lockbox_payload_viewer_service_account_id ) \
  --secret id=$( lockbox_secret_id ),version-id=$( lockbox_secret_version_id ),key=gitlab_runner_token,environment-variable=RUNNER_TOKEN \
  --environment CI_SERVER_URL=$CI_SERVER_URL \
  --environment WEBHOOK_PATH=/webhook \
  --mount type=ephemeral-disk,mount-point=/mnt,size=10GB \
  --async-service-account-id $( gitlab_runner_caller_service_account_id )

container_id(){yc serverless container revision list  --format=json | jq -r '.[].container_id' }
echo $(container_id)


```
Где:
- `folder_id` - id фолдера в вашем облаке, где создан контейнер
- `gitlab_runner_lockbox_payload_viewer_service_account_id` — id сервисного аккаунта с доступом к lockbox секрету
- `lockbox_secret_id` — id lockbox секрета
- `lockbox_secret_version_id` — id версии lockbox секрета
- `gitlab_runner_caller_service_account_id` — id сервисного аккаунта, от имени которого будет вызываться контейнер

Примечание про второй сервисный аккаунт (`gitlab-runner-caller`) - он используется для двух целей одновременно:
1. От его имени GitLab вызывает контейнер (ему назначается роль `serverless-containers.containerInvoker`, а его Api-Key указывается в заголовке `Authorization`).
2. Этот же сервисный аккаунт передаётся в ревизию параметром `--async-service-account-id`, чтобы вызов контейнера выполнялся асинхронно (его ID используется платформой для постановки задачи на выполнение).

При необходимости эти функции можно разделить между разными сервисными аккаунтами: один использовать для вызова контейнера из GitLab (Api-Key), а другой — для асинхронного вызова через параметр `--async-service-account-id`.

Примечание про эфемерный диск:
- Эфемерный диск монтируется в указанный путь (в примере — `/mnt`) и одновременно расширяет доступное пространство корневой файловой системы на время выполнения.
- Docker хранит данные в `/var/lib/docker`; благодаря расширению корневой ФС это пространство также доступно.

### вебхук в GitLab
1. В проекте GitLab: **Settings** → **Webhooks**.
2. URL: публичный endpoint Serverless Containers: `https://<container-id>.containers.yandexcloud.net<WEBHOOK_PATH>`.

container_id(){yc serverless container revision list  --format=json | jq -r '.[].container_id' }
echo $(container_id)

echo hooks: 
echo $CI_SERVER_URL$CI_REPO_HANDLER-/hooks 
echo public endpoint serverless containers: 
echo 'https://'"$(container_id).containers.yandexcloud.net${WEBHOOK_PATH:-/}" 
echo 'https://'"$(container_id).containers.yandexcloud.net${WEBHOOK_PATH:-/}" | xsel -b


3. Заголовки:
    - Secret Token: укажите значение `GITLAB_SECRET` (если используете проверку секрета).
    - `Authorization: Api-Key <ключ_сервисного_аккаунта>` — ключ сервисного аккаунта с правом вызова контейнера. Обязателен при закрытом доступе к контейнеру (иначе запрос будет отклонён). [Документация](https://yandex.cloud/ru/docs/serverless-containers/operations/auth).
    - `X-Ycf-Container-Integration-Type: async` — асинхронный вызов контейнера, платформа вернет 202 сразу. [Документация](TODO).
4. Отметьте событие Job events.
5. Сохраните. Сервис будет реагировать только когда `build_status` = `pending`.

echo "Authorization: Api-Key "

После этого вы можете пользоваться Serverless GitLab Runners!

## Переменные окружения

| Переменная              | По умолчанию         | Обязательно | Описание                                                  |
|-------------------------|----------------------|-------------|-----------------------------------------------------------|
| `RUNNER_TOKEN`          | —                    | да          | Токен GitLab Runner (Project/Group/Instance).             |
| `CI_SERVER_URL`         | `https://gitlab.com` | нет         | Адрес GitLab CI.                                          |
| `PORT`                  | `8080`               | нет         | Порт HTTP.                                                |
| `WEBHOOK_PATH`          | `/`                  | нет         | Путь эндпоинта вебхука.                                   |
| `GITLAB_SECRET`         | —                    | нет         | Секрет для проверки заголовка `X-Gitlab-Token`.           |
| `WAIT_TIMEOUT`          | `10`                 | нет         | Значение для `gitlab-runner --wait-timeout` (в секундах). |
| `MAX_BUILDS`            | `1`                  | нет         | Значение для `gitlab-runner --max-builds`.                |
| `DOCKERD_READY_TIMEOUT` | `5s`                 | нет         | Сколько ждать готовности dockerd (`time.Duration`).       |

### Ограничения
- Поддерживается только Docker executor. Вы можете самостоятельно собрать контейнер со всеми необходимыми зависимостями и использовать в нём shell executor, но это выходит за рамки текущей инструкции.
- Один запрос вебхука запускает одноразовый, эфемерный раннер. Состояние между такими раннерами не сохраняется.
- Задания должны иметь теги, соответствующие тегам раннера. Если у job в `.gitlab-ci.yml` не указаны подходящие теги, раннер не возьмёт задание. Используйте checkbox **Run untagged jobs** при создании раннера, что бы он брал все задачи.

#### Конфигурация раннера
- `gitlab-runner` можно дополнительно конфигурировать через переменные окружения и флаги.
- Посмотрите доступные опции: `gitlab-runner run-single -h` и раздел команд в документации [GitLab Runner commands](https://docs.gitlab.com/runner/commands/).
