terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "1.73.7"
    }
  }
}

provider "huaweicloud" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}


resource "huaweicloud_live_domain" "push_video" {
  name = var.push_domain
  type = "push"
}
resource "huaweicloud_live_domain" "pull_video" {
  name               = var.pull_domain
  type               = "pull"
  service_area = 1
  ingest_domain_name = huaweicloud_live_domain.push_video.name
}

resource "huaweicloud_live_domain" "icp_pull" {
  name               = var.icp_pull_domain
  type               = "pull"
  service_area = 1  
  ingest_domain_name = huaweicloud_live_domain.push_video.name
}
