variable "access_key" {
  description = "Huawei Cloud access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Huawei Cloud secret key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Region to deploy resources"
  type        = string
  default     = "cn-east-3"  # 或你常用的區域
}
variable "ingest_domain_name" {
  description = "推流（Ingest）域名"
  type        = string
}

variable "streaming_domain_name" {
  description = "拉流（Streaming）域名"
  type        = string
}

