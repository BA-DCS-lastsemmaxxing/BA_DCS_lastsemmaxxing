locals {
  s3_origin_id   = "${var.project_name}-origin"
  s3_domain_name = "${var.project_name}.s3.amazonaws.com"  # Updated to regular S3 domain for HTTPS

  api_origin_id   = "${var.project_name}-api-origin"
  api_domain_name = "${aws_api_gateway_rest_api.lsm-fyp-api.id}.execute-api.${var.region}.amazonaws.com"
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

resource "aws_cloudfront_distribution" "cdn" {
  
  enabled = true
  
  origin {
    origin_id                = local.s3_origin_id
    domain_name              = local.s3_domain_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"  # Corrected to support HTTPS
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  origin {
    domain_name = local.api_domain_name
    origin_id   = local.api_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = local.s3_origin_id
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # Custom cache behavior for API Gateway requests, with stricter TTLs
  ordered_cache_behavior {
    path_pattern      = "/api/*"  # Adjust this for API paths
    target_origin_id  = local.api_origin_id
    allowed_methods   = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods    = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 300  # Slightly longer TTL for API responses
    max_ttl                = 3600
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
