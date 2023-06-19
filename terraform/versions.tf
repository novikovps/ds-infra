terraform {
  required_version = ">= 1.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    region     = "ru-central1"

    bucket     = "tf-state-bucket-ds"
    key        = "tf.state"

    skip_region_validation      = true
    skip_credentials_validation = true

    dynamodb_endpoint = "https://docapi.serverless.yandexcloud.net/ru-central1/b1gpg5c2qrk27vi7l869/etnmmbp0c0mfsttn5v68"
    dynamodb_table = "tf-state"
  }
}

provider "yandex" {}