# store the terraform state file in s3
terraform {
  backend "s3" {
    bucket    = "bajogab2-terraform-remote-state"
    key       = "Jupiter-Website-ECS.tfstate"
    region    = "us-east-1"
    profile   = "terraform-user"
  }
}