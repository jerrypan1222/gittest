terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "1.73.7"
    }
  }
}
variable "cert_name" {}
variable "cert_file" {}
variable "key_file" {}


# 1080p Live Domain Module
module "live_domain_1080" {
  source             = "./modules/livedomain"
  access_key         = var.access_key
  secret_key         = var.secret_key
  region             = var.region
  push_domain        = var.push_domain_1080
  pull_domain        = var.pull_domain_1080
  icp_pull_domain    = var.icp_pull_domain_1080
}


# 720p Live Domain Module
module "live_domain_720" {
  source             = "./modules/livedomain"
  access_key         = var.access_key
  secret_key         = var.secret_key
  region             = var.region
  push_domain        = var.push_domain_720
  pull_domain        = var.pull_domain_720
  icp_pull_domain    = var.icp_pull_domain_720
}


resource "null_resource" "create_certificate" {
  provisioner "local-exec" {
    command = "hwcloud live create-certificate --cert-name ${var.cert_name} --cert-content file://${var.cert_file} --private-key file://${var.key_file}"
  }

  triggers = {
    cert_name = var.cert_name
  }

  depends_on = [
    module.live_domain_1080,
    module.live_domain_720
  ]
}


resource "null_resource" "update_certificate" {
  provisioner "local-exec" {
    command = "hwcloud live update-certificate --cert-name ${var.cert_name} --cert-content file://${var.cert_file} --private-key file://${var.key_file}"
  }

  triggers = {
    cert_hash = filesha256(var.cert_file)
    key_hash  = filesha256(var.key_file)
  }

  depends_on = [
    module.live_domain_1080,
    module.live_domain_720
  ]
}

