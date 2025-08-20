# =============================================
# Backend - STAGING Environment
# =============================================
terraform {
  backend "s3" {
    bucket  = "collectalot-tf-state"
    key     = "environments/staging/infra/terraform.tfstate"
    region  = "us-east-1"
  }
}
