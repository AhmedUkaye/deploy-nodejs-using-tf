terraform {
  backend "s3" {
    bucket         = "nodejs-mongo-webapp-bucket"
    key            = "terraform-statefile/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "nodejs-mongo-webapp-terraformlock"
    encrypt        = true
  }
}
