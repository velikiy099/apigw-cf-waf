include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../modules/stack"
}

inputs = {
  project_name = "apigw-cf-waf"
  environment  = "dev"
  region       = "ap-northeast-1"

  # Replace these with your corporate egress CIDRs.
  # The TEST-NET placeholder avoids accidental access from real clients.
  corporate_ipv4_cidrs = ["203.0.113.0/24"]
  corporate_ipv6_cidrs = []

  # Do not commit a real value. Export ORIGIN_VERIFY_SECRET before running Terragrunt.
  # Example: export ORIGIN_VERIFY_SECRET=$(openssl rand -base64 32)
  origin_verify_secret      = get_env("ORIGIN_VERIFY_SECRET", "replace-me-with-at-least-32-random-chars")
  origin_verify_header_name = "x-origin-verify"

  api_stage_name                 = "prod"
  api_resource_server_identifier = "api"
  api_scope_name                 = "invoke"

  enable_waf_managed_rules = true
  cloudfront_rate_limit    = 2000
  api_rate_limit           = 1000
}
