# Инфраструктурный репозиторий Dumplings store (Учебный проект)
## Общее описание
Все компоненты сервиса dumplings-store работают в контейнерах Docker под управлением Managed K8s cluster.
> `Обращаю внимание, что CI/CD написан для Gitlab.`

Образы компонентов приложения, а также сервисные образы хранятся в Gitlab container registry.
Инфраструктура развёрнута в облаке (провайдер Yandex Cloud) с помощью Terraform.
Приложение развёрнуто в Managed k8s cluster с помощью helm-чарт.
Helm-чарты версионируются согласно SemVer, хранятся в Nexus.
Для доступа к приложению из-вне используется Traefik.
Мониторинг осуществляется с помощью связки prometheus-grafana, логирование - Loki.

## Технический стек
| Task          | Tool          | Version   |
| ----          | ----          | -------   |
|CI/CD  |gitlab |  Enterprise Edition 15.3.1-ee        |
|Container  |docker |     20.10.12      |
|Container registry  |gitlab |    Enterprise Edition 15.3.1-ee       |
|Infrastructure provisioning    |terraform  |   >= 1.0.0        |
|Cloud provider|Yandex Cloud| >= 0.90.0|
|Container orchestration    |managed kubernetes |           |
|K8s package manager         |helm         |    3.11.3       |
|Helm-chart registry          |nexus         |      OSS 3.34.1-01     |
|Reverse-proxy/Ingress          |traefik        |      23.0.1     |
|Monitoring  |prometheus         |  prometheus-community/kube-prometheus-stack 45.28.1|
|Dashboard          |grafana         |   prometheus-community/kube-prometheus-stack 45.28.1|
|Logging          |loki         |  grafana/loki 5.5.2    |

## Развёртывание инфраструктуры
Все инструкции приведены для Ubuntu 22.04.1 LTS.
## Предварительная настройка
### Prerquestes:
- аккаунт в Yandex Cloud
- установленная Yandex Cloud command-line interface (CLI) (настроенная на работу с облаком/папкой)
- установленный kubectl
- установленный helm
- установленный jq
### Выполнить операции в web-интерфейсе
1. Создать облако
```
Name: store
```
2. Создать папку
```
Name: dumplings-store
```
3. Создать bucket Object Storage/Buckets/tf-state-bucket-ds
```
Name: tf-state-bucket-ds
Encription: True
KMS-key (Create new): tf-state-bucket-key
```
4. Создать Managed Service for YDB/Database/tf-state-ydb
```
Name: tf-state-ydb
Type: Serverless
```
5. Создать таблицу в БД Managed Service for YDB/Databases/tf-state-ydb
```
Name: tf-state
Table type: Document table
Columns (delete all and create only one): LockID 
```
### Выполнить операции в yc-cli
1. Создать сервис аккаунт для terraform
```
yc iam service-account create --name sa-tf 
```
2. Добавить роли для сервисного аккаунта
```
yc resource-manager folder add-access-binding --service-account-name sa-tf --role admin dumplings-store 
```
3. Создать access-key для сервисного аккаунта (для работы с s3)
```
yc iam access-key create --service-account-name sa-tf
```
4. Сохранить полученный ключ в переменные в Gitlab
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```
5. Создать IAM-ключ для сервисного аккаунта (для возможности создавать/удалять ресурсы)
```
yc iam key create --service-account-name sa-tf --output sa-key.json
```
6. Сохранить полученный ключ в переменную Gitlab
```
cat sa-key.json
YC_key
```
7. Добавить переменные в Gitlab
```
YC_CLOUD_ID     (yc config get cloud-id)
YC_FOLDER_ID    (yc config get folder-id)
```
8. Внести актуальные данные в файл ./terraform/versions.tf (bucket, key, dynamodb_endpoint, dynamodb_table)

### Запуск pipeline
При внесения изменений в файл versions.tf и push изменений в репозиторий, инфраструктурный pipeline запустится автоматически.
Однако, для развёртывания инфраструктуры потребуется запустить deploy вручную.

### Настройка K8s
1. После развёртывания инфраструктуры, требуется посмотреть результат выполнения deploy-job.
Вывод будет таким:
```
yc managed-kubernetes cluster get-credentials --id *** --external
```
Данная команда настроит config для подключения к k8s (создаст ~/.kube/config, и задаст контекст).
2. Создать сервисный аккаунт в K8s для работы с Gitlab
```
kubectl apply -f ./k8s/gitlab/gitlab-admin-service-account.yaml
```
3. Получить токен для созданного аккаунта и сохранить его в переменную в Gitlab
```
kubectl -n kube-system get secrets -o json | \
jq -r '.items[] | select(.metadata.name | startswith("gitlab-admin")) | .data.token' | \
base64 --decode

KUBE_TOKEN
```
4. Получить внешний ip-адрес кластера и сохранить его в переменную в Gitlab
```
kubectl cluster-info

KUBE_URL
```
### Установка helm-charts
1. Добавить переменные в Gitlab
```
NEXUS_REPOSITORY - URL репозитория
NEXUS_USERNAME - nexus логин
NEXUS_PASSWORD - nexus пароль
DS_CHART_DOCKER_JSON - JSON для аутентификации в container registry в формате base64
DS_BACKEND_IMAGE - репозиторий с контейнером backend
DS_FRONTEND_IMAGE - репозиторий с контейнером backend
DS_FQDN - внешнее имя сервиса
DS_CHART_DOCKER_JSON - аутентификационные данные для доступа к container registry из k8s
```
2. Добавить helm-repos
> При добавлении репозитория nexus требуется подставить актуальные данные вместо переменных
```
helm repo add traefik https://traefik.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add nexus NEXUS_REPOSITORY --username NEXUS_USERNAME --password NEXUS_PASSWORD
helm repo update
```
3. Установить traefik
```
helm install traefik traefik/traefik --values ./k8s/traefik/setup_values.yml -n traefik --create-namespace
```
Посмотреть внешний ip-адрес traefik и добавить соответствующую у DNS-провайдера:
```
kubectl -n traefik get service/traefik
```
4. Установить средства мониторинга
```
helm install prometheus prometheus-community/prometheus -n prometheus --create-namespace
```
5. Установить средства логирования
```
helm install loki grafana/loki --values ./k8s/loki/setup_values.yml -n loki --create-namespace
```
6. Установить средства визуализации мониторинга
```
helm install grafana grafana/grafana --values ./k8s/grafana/setup_values.yml -n grafana --create-namespace
```
7. Установить актуальную версию dumpling-store
```
helm install dumplings-store nexus/dumplings-store -n dumplings-store --create-namespace
```

Как и для репозитория приложения, для инфраструктурного репозитория добавлен CI-pipeline.
Pipeline запускается автоматически в случае изменений в каталогах ds-charts и terraform.
Deploy-stage требует ручного запуска.
Приложение, в случае изменений, всегда разворачивается через pipeline ds-charts, который запускается триггером из pipeline приложения.
Если необходим ручной запуск pipeline, добавлена переменная RUN_PIPELINE.
