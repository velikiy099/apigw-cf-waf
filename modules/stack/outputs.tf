output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.app.id
}

output "cloudfront_domain_name" {
  description = "CloudFront generated domain name."
  value       = aws_cloudfront_distribution.app.domain_name
}

output "application_url" {
  description = "Application URL using the CloudFront generated domain."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "frontend_bucket_name" {
  description = "S3 bucket for frontend assets."
  value       = aws_s3_bucket.frontend.bucket
}

output "api_gateway_invoke_url" {
  description = "Direct API Gateway invoke URL. This should be blocked for non-CloudFront sources by the API Gateway WAF."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "api_url_via_cloudfront" {
  description = "API base URL through CloudFront."
  value       = "https://${aws_cloudfront_distribution.app.domain_name}/api"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito SPA app client ID."
  value       = aws_cognito_user_pool_client.spa.id
}

output "cognito_hosted_ui_domain" {
  description = "Cognito Hosted UI domain."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.region}.amazoncognito.com"
}

output "api_oauth_scope" {
  description = "Custom OAuth scope required by API Gateway methods by default."
  value       = local.api_invoke_scope
}

output "cognito_login_url" {
  description = "Example Cognito Hosted UI login URL. The SPA should add state, nonce, code_challenge, and code_challenge_method=S256 for PKCE."
  value = format(
    "https://%s.auth.%s.amazoncognito.com/oauth2/authorize?client_id=%s&response_type=code&scope=%s&redirect_uri=%s",
    aws_cognito_user_pool_domain.this.domain,
    var.region,
    aws_cognito_user_pool_client.spa.id,
    join("+", [for scope in local.oauth_scopes : urlencode(scope)]),
    urlencode(format("https://%s/callback", aws_cloudfront_distribution.app.domain_name))
  )
}

output "cloudfront_waf_web_acl_arn" {
  description = "CloudFront WAF Web ACL ARN."
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "api_gateway_waf_web_acl_arn" {
  description = "API Gateway WAF Web ACL ARN."
  value       = aws_wafv2_web_acl.api_gateway.arn
}
