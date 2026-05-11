# State key is supplied at init time via -backend-config so the same
# config can manage both staging and prod with separate state files:
#
#   terraform init -backend-config="key=dbservice/staging/terraform.tfstate"
#   terraform init -backend-config="key=dbservice/prod/terraform.tfstate"
terraform {
  backend "s3" {
    bucket  = "111766607077-dbservice-test-terraform-state"
    region  = "ap-south-1"
    encrypt = true
  }
}
