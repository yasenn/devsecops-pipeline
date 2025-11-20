terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}


resource "yandex_serverless_container" "serverless-gitlab-runner" {

  name               = "serverless"
  memory             = 1024
  service_account_id = yandex_iam_service_account.gitlab-runner-caller.id
  image {
    url = "cr.yandex/yc/serverless/gitlab-runner"
  }
  mounts {
    mount_point_path = "/etc/gitlab-runner"
    mode             = "rw"
    object_storage {
      bucket = yandex_storage_bucket.var-lib-docker.bucket
      prefix = "/etc/gitlab-runnner"
    }
  }
  mounts {
    mount_point_path = "/var/lib/docker"
    mode             = "rw"
    object_storage {
      bucket = yandex_storage_bucket.var-lib-docker.bucket
      prefix = "/var/lib/docker"
    }
  }
}
resource "yandex_serverless_container_iam_binding" "container-iam" {
  container_id = yandex_serverless_container.serverless-gitlab-runner.id
  role         = "serverless.containers.invoker"

  members = [
    "system:allUsers",
  ]
}

resource "yandex_iam_service_account" "gitlab-runner-lockbox-payload-viewer" {
# terraform import yandex_iam_service_account.gitlab-runner-lockbox-payload-viewer $(yc iam service-account get --name gitlab-runner-lockbox-payload-viewer --format json | jq -r .id)
  folder_id = var.yc_folder_id
  name      = "gitlab-runner-lockbox-payload-viewer"
}
resource "yandex_iam_service_account" "gitlab-runner-caller" {
# terraform import yandex_iam_service_account.gitlab-runner-caller $(yc iam service-account get --name gitlab-runner-caller --format json | jq -r .id)
  folder_id = var.yc_folder_id
  name      = "gitlab-runner-caller"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.gitlab-runner-caller.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "sa-admin" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.gitlab-runner-caller.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.gitlab-runner-caller.id
  description        = "static access key for object storage"
}

resource "yandex_storage_bucket" "var-lib-docker" {
# terraform import yandex_storage_bucket.var-lib-docker var-lib-docker
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "var-lib-docker"
}
