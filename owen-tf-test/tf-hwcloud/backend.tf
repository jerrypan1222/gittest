  backend "s3" {
    endpoint                    = "https://minio.fb-infra.com:9000"                 # MinIO 的地址
    bucket                      = "wt-prod-cloudflare-terraform"                    # 你在 MinIO 上创建的 bucket 名称
    key                         = "prod/fb-infra.com/loadblancer/terraform.tfstate" # Terraform 状态文件的路径
    region                      = "main"                                            # 选择一个默认的 region
    access_key                  = "UuAnj4GIdU1Y76ud2lYu"                            # MinIO 的 access key
    secret_key                  = "EWKLat3T0waaMGVX74A801x4QxzOojAaPo0bAW29"        # MinIO 的 secret key
    skip_requesting_account_id  = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
