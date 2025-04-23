resource "huaweicloud_live_domain" "ingestDomain" {
  name = var.ingest_domain_name
  type = "push"
}

resource "huaweicloud_live_domain" "streamingDomain" {
  name               = var.streaming_domain_name
  type               = "pull"
  ingest_domain_name = huaweicloud_live_domain.ingestDomain.name
  service_area = 1
}

