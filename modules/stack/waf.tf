resource "aws_wafv2_ip_set" "corporate_ipv4" {
  provider = aws.us_east_1
  count    = length(var.corporate_ipv4_cidrs) > 0 ? 1 : 0

  name               = "${local.name_prefix}-corporate-ipv4"
  description        = "Corporate IPv4 ranges allowed to access CloudFront."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.corporate_ipv4_cidrs

  tags = local.tags
}

resource "aws_wafv2_ip_set" "corporate_ipv6" {
  provider = aws.us_east_1
  count    = length(var.corporate_ipv6_cidrs) > 0 ? 1 : 0

  name               = "${local.name_prefix}-corporate-ipv6"
  description        = "Corporate IPv6 ranges allowed to access CloudFront."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV6"
  addresses          = var.corporate_ipv6_cidrs

  tags = local.tags
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1

  name        = "${local.name_prefix}-cloudfront-acl"
  description = "Allows only corporate CIDRs to reach CloudFront."
  scope       = "CLOUDFRONT"

  default_action {
    block {}
  }

  dynamic "rule" {
    for_each = var.enable_waf_managed_rules ? [1] : []

    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 0

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "CFManagedCommon"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "CloudFrontRateLimit"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.cloudfront_rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CFRateLimit"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(var.corporate_ipv4_cidrs) > 0 ? [1] : []

    content {
      name     = "AllowCorporateIPv4"
      priority = 100

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.corporate_ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "CFAllowCorpIPv4"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(var.corporate_ipv6_cidrs) > 0 ? [1] : []

    content {
      name     = "AllowCorporateIPv6"
      priority = 101

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.corporate_ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "CFAllowCorpIPv6"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudFrontAcl"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_ip_set" "cloudfront_ipv4" {
  count = length(local.cloudfront_origin_facing_ipv4_cidrs) > 0 ? 1 : 0

  name               = "${local.name_prefix}-cloudfront-ipv4"
  description        = "CloudFront origin-facing IPv4 ranges allowed to reach API Gateway."
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = local.cloudfront_origin_facing_ipv4_cidrs

  tags = local.tags
}

resource "aws_wafv2_ip_set" "cloudfront_ipv6" {
  count = length(local.cloudfront_origin_facing_ipv6_cidrs) > 0 ? 1 : 0

  name               = "${local.name_prefix}-cloudfront-ipv6"
  description        = "CloudFront origin-facing IPv6 ranges allowed to reach API Gateway."
  scope              = "REGIONAL"
  ip_address_version = "IPV6"
  addresses          = local.cloudfront_origin_facing_ipv6_cidrs

  tags = local.tags
}

resource "aws_wafv2_web_acl" "api_gateway" {
  name        = "${local.name_prefix}-api-acl"
  description = "Allows only CloudFront origin-facing IPs with the expected origin verification header."
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  dynamic "rule" {
    for_each = var.enable_waf_managed_rules ? [1] : []

    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 0

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "APIManagedCommon"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "ApiGatewayRateLimit"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.api_rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "APIRateLimit"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = length(local.cloudfront_origin_facing_ipv4_cidrs) > 0 ? [1] : []

    content {
      name     = "AllowCloudFrontIPv4WithOriginSecret"
      priority = 100

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.cloudfront_ipv4[0].arn
            }
          }

          statement {
            byte_match_statement {
              field_to_match {
                single_header {
                  name = lower(var.origin_verify_header_name)
                }
              }

              positional_constraint = "EXACTLY"
              search_string         = var.origin_verify_secret

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "APIAllowCFIPv4Secret"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(local.cloudfront_origin_facing_ipv6_cidrs) > 0 ? [1] : []

    content {
      name     = "AllowCloudFrontIPv6WithOriginSecret"
      priority = 101

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.cloudfront_ipv6[0].arn
            }
          }

          statement {
            byte_match_statement {
              field_to_match {
                single_header {
                  name = lower(var.origin_verify_header_name)
                }
              }

              positional_constraint = "EXACTLY"
              search_string         = var.origin_verify_secret

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "APIAllowCFIPv6Secret"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ApiGatewayAcl"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway.arn
}
