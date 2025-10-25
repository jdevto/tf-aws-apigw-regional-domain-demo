# Data source to get the Route 53 hosted zone
data "aws_route53_zone" "this" {
  name = var.domain_name
}

# Data source to get current AWS region
data "aws_region" "current" {}

# Get current user's public IP
data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com/"
}

# ACM Certificate for wildcard domain (Regional - same region as API Gateway)
resource "aws_acm_certificate" "this" {
  domain_name               = local.wildcard_domain
  validation_method         = "DNS"
  subject_alternative_names = []

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, {
    Name = local.name
  })
}

# ACM Certificate validation records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "this" {
  name        = local.name
  description = "Regional API Gateway Demo with Custom Domain"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.tags, {
    Name = local.name
  })
}

# API Gateway Resource Policy for IP-based access control
resource "aws_api_gateway_rest_api_policy" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.this.execution_arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = ["${trimspace(data.http.my_public_ip.response_body)}/32"]
          }
        }
      }
    ]
  })
}

# API Gateway Resource for /hello endpoint
resource "aws_api_gateway_resource" "hello" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "hello"
}

# API Gateway Method for GET /hello
resource "aws_api_gateway_method" "hello_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.hello.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for mock response
resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.hello_get.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "hello_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.hello_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "hello_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.hello.id
  http_method = aws_api_gateway_method.hello_get.http_method
  status_code = aws_api_gateway_method_response.hello_response.status_code

  response_templates = {
    "application/json" = jsonencode({
      message   = "Hello from Regional API Gateway!"
      timestamp = "$context.requestTime"
      domain    = local.custom_domain_name
    })
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# API Gateway Resource for /status endpoint
resource "aws_api_gateway_resource" "status" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "status"
}

# API Gateway Method for GET /status
resource "aws_api_gateway_method" "status_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.status.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for status mock response
resource "aws_api_gateway_integration" "status_integration" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_get.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# API Gateway Method Response for status
resource "aws_api_gateway_method_response" "status_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response for status
resource "aws_api_gateway_integration_response" "status_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_get.http_method
  status_code = aws_api_gateway_method_response.status_response.status_code

  response_templates = {
    "application/json" = jsonencode({
      status    = "healthy"
      service   = "Regional API Gateway Demo"
      version   = "1.0.0"
      timestamp = "$context.requestTime"
      region    = data.aws_region.current.region
      domain    = local.custom_domain_name
    })
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# API Gateway Method for GET / (root)
resource "aws_api_gateway_method" "root_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for root mock response
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_rest_api.this.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# API Gateway Method Response for root
resource "aws_api_gateway_method_response" "root_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_rest_api.this.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response for root
resource "aws_api_gateway_integration_response" "root_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_rest_api.this.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method
  status_code = aws_api_gateway_method_response.root_response.status_code

  response_templates = {
    "application/json" = jsonencode({
      api_name    = local.name
      description = "Demo API with custom domain and wildcard certificate"
      endpoints = [
        "GET / - API information and metadata",
        "GET /hello - Simple greeting message",
        "GET /status - Health check endpoint"
      ]
      certificate   = local.wildcard_domain
      custom_domain = local.custom_domain_name
      region        = data.aws_region.current.region
      timestamp     = "$context.requestTime"
    })
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.hello_integration,
    aws_api_gateway_integration_response.hello_integration_response,
    aws_api_gateway_integration.status_integration,
    aws_api_gateway_integration_response.status_integration_response,
    aws_api_gateway_integration.root_integration,
    aws_api_gateway_integration_response.root_integration_response,
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = local.environment

  # Enable X-Ray tracing
  xray_tracing_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name}-stage"
  })
}

# API Gateway Method Settings
resource "aws_api_gateway_method_settings" "this" {
  depends_on = [
    aws_api_gateway_stage.this
  ]

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "OFF"
    data_trace_enabled = false
    metrics_enabled    = true
  }
}

# API Gateway Custom Domain
resource "aws_api_gateway_domain_name" "this" {
  domain_name              = local.custom_domain_name
  regional_certificate_arn = aws_acm_certificate_validation.this.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(local.tags, {
    Name = local.name
  })
}

# API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "this" {
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this.domain_name
}

# Route 53 A record pointing to API Gateway
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.custom_domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.this.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this.regional_zone_id
    evaluate_target_health = false
  }
}
