data "aws_caller_identity" "current" {}

data "http" "aws_ip_ranges" {
  url = "https://ip-ranges.amazonaws.com/ip-ranges.json"

  request_headers = {
    Accept = "application/json"
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host_header" {
  name = "Managed-AllViewerExceptHostHeader"
}
