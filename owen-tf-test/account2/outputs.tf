output "ingest_domain" {
  description = "推流（Ingest）域名"
  value       = huaweicloud_live_domain.ingestDomain.name
}

output "streaming_domain" {
  description = "拉流（Streaming）域名"
  value       = huaweicloud_live_domain.streamingDomain.name
}

