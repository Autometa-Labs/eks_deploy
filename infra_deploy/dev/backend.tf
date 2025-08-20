# =============================================
# Backend - DEV Environment
# =============================================
terraform {
  backend "s3" {
    bucket  = "collectalot-tf-state"
    key     = "environments/dev/infra/terraform.tfstate"
    region  = "us-east-1"
  }
}
