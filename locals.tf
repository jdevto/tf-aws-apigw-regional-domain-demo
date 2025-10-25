locals {
  # Full custom domain name for the API Gateway
  custom_domain_name = "${var.subdomain}.${var.namespace}.${var.domain_name}"

  # Wildcard domain for ACM certificate
  wildcard_domain = "*.${var.namespace}.${var.domain_name}"

  name        = "apigw-regional"
  environment = "dev"

  tags = {
    Project     = "api-gateway-regional-demo"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}
