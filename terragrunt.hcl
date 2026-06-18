locals {
  project = "apigw-cf-waf"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = "${local.project}-tfstate-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "${local.project}-tf-lock-${get_aws_account_id()}"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF_PROVIDER
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}

provider "aws" {
  region = var.region
}

# CloudFront WAFv2 Web ACLs are global and must be managed in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
EOF_PROVIDER
}
