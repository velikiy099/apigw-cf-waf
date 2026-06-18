locals {
  name_prefix = lower("${var.project_name}-${var.environment}")

  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform-terragrunt"
    }
  )

  aws_ip_ranges = jsondecode(data.http.aws_ip_ranges.response_body)

  cloudfront_origin_facing_ipv4_cidrs = length(var.cloudfront_origin_facing_ipv4_cidrs_override) > 0 ? var.cloudfront_origin_facing_ipv4_cidrs_override : sort([
    for prefix in local.aws_ip_ranges.prefixes : prefix.ip_prefix
    if prefix.service == "CLOUDFRONT"
  ])

  cloudfront_origin_facing_ipv6_cidrs = length(var.cloudfront_origin_facing_ipv6_cidrs_override) > 0 ? var.cloudfront_origin_facing_ipv6_cidrs_override : sort([
    for prefix in local.aws_ip_ranges.ipv6_prefixes : prefix.ipv6_prefix
    if prefix.service == "CLOUDFRONT"
  ])

  frontend_bucket_name = substr(lower(replace("${local.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.region}-frontend", "_", "-")), 0, 63)
  cognito_domain      = substr(lower(replace("${local.name_prefix}-${data.aws_caller_identity.current.account_id}", "_", "-")), 0, 63)

  api_resource_server_identifier = var.api_resource_server_identifier
  api_invoke_scope_name          = var.api_scope_name
  api_invoke_scope               = "${local.api_resource_server_identifier}/${local.api_invoke_scope_name}"
  oauth_scopes                   = distinct(concat(var.oauth_standard_scopes, [local.api_invoke_scope]))

  s3_origin_id  = "${local.name_prefix}-s3-frontend"
  api_origin_id = "${local.name_prefix}-api-gateway"
}
