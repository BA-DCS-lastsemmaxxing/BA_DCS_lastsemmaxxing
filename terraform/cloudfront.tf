locals {
  s3_origin_id   = "${var.project_name}-frontend-origin"
  s3_domain_name = "${var.project_name}-frontend.s3.${var.region}.amazonaws.com"  # Updated to regular S3 domain for HTTPS
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name = "${var.project_name}-oac"
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
  description = "WAF for API Gateway and CloudFront-S3 security"

  default_action {
    block {}  # Block all requests unless explicitly allowed
  }

  rule {
  name     = "AllowCORSPreflight"
  priority = 1

  action {
    allow {}
  }

  statement {
    byte_match_statement {
      field_to_match {
        method {}
      }
      positional_constraint = "EXACTLY"
      search_string         = "OPTIONS"
      text_transformation {
        priority = 0
        type     = "NONE"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AllowCORSPreflight"
    sampled_requests_enabled   = true
  }
}

  # 1️⃣ Allow API Gateway Requests with JWT Authentication
  # 1️⃣ Allow API Gateway Requests with JWT Authentication
  rule {
    name     = "AllowJWTAuthToAPI"
    priority = 2

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "authorization"  # Change from "cookie" to "Authorization"
          }
        }
        positional_constraint = "STARTS_WITH"
        search_string         = "ey" 
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowJWTAuthToAPI"
      sampled_requests_enabled   = true
    }
  }


  # # 2️⃣ Rate Limiting for API Gateway (e.g., 100 requests per 5 minutes)
  # rule {
  #   name     = "RateLimitAPIRequests"
  #   priority = 3

  #   action {
  #     block {}
  #   }

  #   statement {
  #     rate_based_statement {
  #       limit              = 1000  # Adjust based on expected traffic
  #       aggregate_key_type = "IP"
  #     }
  #   }

  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "RateLimitAPIRequests"
  #     sampled_requests_enabled   = true
  #   }
  # }

  # 3️⃣ SQL Injection & XSS Protection for API Gateway
  rule {
    name     = "SQLInjectionAndXSSProtection"
    priority = 4

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          sqli_match_statement {
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "URL_DECODE"
            }
          }
        }

        statement {
          xss_match_statement {
            field_to_match {
              all_query_arguments {}
            }
            text_transformation {
              priority = 0
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLInjectionAndXSSProtection"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAFLogging"
    sampled_requests_enabled   = true
  }
}

# Associate WAF with API Gateway
resource "aws_wafv2_web_acl_association" "waf_api_assoc" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_acl.arn

  depends_on = [ aws_api_gateway_stage.prod, aws_wafv2_web_acl.waf_acl ]
}
