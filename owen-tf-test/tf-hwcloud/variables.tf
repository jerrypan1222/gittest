variable "push_domain_1080" {
  type = string
}
variable "pull_domain_1080" {
  type = string
}
variable "icp_pull_domain_1080" {
  type = string
}

variable "push_domain_720" {
  type = string
}
variable "pull_domain_720" {
  type = string
}
variable "icp_pull_domain_720" {
  type = string
}
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
