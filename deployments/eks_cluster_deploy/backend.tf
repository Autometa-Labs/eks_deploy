# =============================================
# Backend
# =============================================
terraform {
  backend "s3" {
    bucket  = "collectalot-tf-state"
    key     = "dev-app-cluster/dev-app-01.tfstate"
    region  = "us-east-1"
  }
}