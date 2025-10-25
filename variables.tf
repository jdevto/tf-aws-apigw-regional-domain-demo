variable "domain_name" {
  description = "The domain name for the Route 53 hosted zone (e.g., dev.example.com)"
  type        = string
}

variable "namespace" {
  description = "Subdomain prefix for isolation (e.g., group1)"
  type        = string
}

variable "subdomain" {
  description = "Specific API subdomain (e.g., web, customer1)"
  type        = string
}
