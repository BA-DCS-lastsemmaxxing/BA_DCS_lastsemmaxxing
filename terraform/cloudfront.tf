locals {
  s3_origin_id   = "${var.project_name}-frontend-origin"
  s3_domain_name = "${var.project_name}-frontend.s3.${var.region}.amazonaws.com"  # Updated to regular S3 domain for HTTPS

  api_origin_id   = "${var.project_name}-api-origin"
  api_domain_name = "${aws_api_gateway_rest_api.lsm-fyp-api.id}.execute-api.${var.region}.amazonaws.com"
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name = "lsm-fyp-oac"
  description = "OAC for S3 Frontend Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

# IAM role for CloudFront to sign requests
resource "aws_iam_role" "cloudfront_role" {
  name = "${var.project_name}-cloudfront-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudfront_sigv4_policy" {
  name = "${var.project_name}-cloudfront-sigv4-policy"
  description = "Allow CloudFront to sign API Gateway Requests"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["execute-api:Invoke"]
        Resource = "${aws_api_gateway_rest_api.lsm-fyp-api.execution_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudfront_policy_attachment" {
  role       = aws_iam_role.cloudfront_role.name
  policy_arn = aws_iam_policy.cloudfront_sigv4_policy.arn
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "managed_origin_request_policy" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true
  default_root_object = "index.html"
  
  origin {
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    domain_name              = local.s3_domain_name
  }

  origin {
    domain_name = local.api_domain_name
    origin_id   = local.api_origin_id
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  # Custom cache behavior for API Gateway requests, with stricter TTLs
  ordered_cache_behavior {
    path_pattern      = "/api/*"  # Adjust this for API paths
    target_origin_id  = local.api_origin_id
    allowed_methods   = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods    = ["GET", "HEAD"]

    origin_request_policy_id = "Managed-AllViewer"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0  # Disable caching to avoid auth issues
    max_ttl                = 0
  }

    default_cache_behavior {
    target_origin_id = local.s3_origin_id
    allowed_methods = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.managed_origin_request_policy.id

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = aws_lambda_function.auth_lambda_edge.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# AWS WAF Web ACL
resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "${var.project_name}-waf-acl"
  scope       = "REGIONAL"
  description = "WAF to restrict non-CloudFront requests"

  default_action {
    allow {}
  }

  rule {
    name     = "AllowOnlyCloudFront"
    priority = 1

    action {
      block {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "authorization"
          }
        }
        positional_constraint = "EXACTLY"
        search_string         = "AWS4-HMAC-SHA256"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowOnlyCloudFront"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AllowOnlyCloudFront"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "waf_api_assoc" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_acl.arn
}
