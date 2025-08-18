# =============================================
# Backend - PROD Environment
# =============================================
terraform {
  backend "s3" {
    bucket  = "collectalot-tf-state"
    key     = "environments/prod/infra/terraform.tfstate"
    region  = "us-east-1"
  }
}
