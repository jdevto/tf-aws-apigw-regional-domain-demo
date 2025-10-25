output "custom_domain_url" {
  description = "The custom domain URL for the API Gateway"
  value       = "https://${local.custom_domain_name}"
}

output "api_gateway_invoke_url" {
  description = "The API Gateway invoke URL"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}"
}

output "test_curl_command" {
  description = "Curl command to test the /hello endpoint"
  value       = "curl -X GET https://${local.custom_domain_name}/hello"
}

output "test_commands" {
  description = "Curl commands to test all API endpoints"
  value = {
    root   = "curl -X GET https://${local.custom_domain_name}/"
    hello  = "curl -X GET https://${local.custom_domain_name}/hello"
    status = "curl -X GET https://${local.custom_domain_name}/status"
  }
}
