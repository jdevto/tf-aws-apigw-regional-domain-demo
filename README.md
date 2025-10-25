# Regional API Gateway with Custom Domain

A Terraform configuration for deploying a Regional Amazon API Gateway with a custom domain, wildcard ACM certificate, and Route 53 DNS.

## What This Creates

This configuration creates a Regional API Gateway setup with:

- Custom domain using wildcard certificate (e.g., `*.group1.dev.example.com`)
- Regional API Gateway (not edge-optimized)
- Single Route 53 hosted zone and ACM certificate
- Basic IP-based access control
- HTTPS via ACM-issued certificate

## Architecture

```plaintext
┌─────────────────────────────────────────────────────────────┐
│                    Route 53 Hosted Zone                    │
│                      dev.example.com                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ├── web.group1.dev.example.com (A record)
                      ├── customer1.group1.dev.example.com
                      ├── customer2.group1.dev.example.com
                      └── _abc123.group1.dev.example.com (ACM validation)
                                                              │
┌─────────────────────────────────────────────────────────────┼─┐
│                    ACM Certificate                         │ │
│                 *.group1.dev.example.com                   │ │
└─────────────────────────────────────────────────────────────┼─┘
                                                              │
┌─────────────────────────────────────────────────────────────┼─┐
│                API Gateway Custom Domain                   │ │
│              web.group1.dev.example.com                    │ │
└─────────────────────┬───────────────────────────────────────┼─┘
                      │                                       │
                      ├── Base Path Mapping                   │
                      │   (/) → API Gateway REST API          │
                      │                                       │
┌─────────────────────┴───────────────────────────────────────┼─┐
│                Regional API Gateway                        │ │
│                    REST API                                │ │
│                                                             │ │
│  GET / → API information and metadata                      │ │
│  GET /hello → Simple greeting message                      │ │
│  GET /status → Health check endpoint                       │ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Existing Route 53 Hosted Zone**: You need an existing Route 53 hosted zone (e.g., `dev.example.com`)
2. **AWS CLI configured** with appropriate permissions
3. **Terraform** installed (version 1.0+)

## Required AWS Permissions

Your AWS credentials need permissions for:

- Route 53 (read hosted zone, create records)
- ACM (create certificate, validate certificate) - **in `ap-southeast-2` (same region as API Gateway)**
- API Gateway (create REST API, custom domain, base path mapping, resource policies)
- CloudFormation (for API Gateway deployments)
- HTTP (for automatic IP detection)

**Important**: ACM certificates for Regional API Gateway custom domains must be created in the same region as the API Gateway (`ap-southeast-2`), not `us-east-1`.

## Usage

### 1. Configure Variables

Create a `terraform.tfvars` file with your specific values:

```hcl
domain_name = "dev.example.com"    # Your existing hosted zone
namespace   = "group1"            # Subdomain prefix for isolation
subdomain   = "web"               # Specific API subdomain
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 3. Test the API

After deployment, test the API using the provided curl commands:

```bash
# Get all test commands from Terraform output
terraform output test_commands

# Test individual endpoints
curl -X GET https://web.group1.dev.example.com/
curl -X GET https://web.group1.dev.example.com/hello
curl -X GET https://web.group1.dev.example.com/status
```

**Expected Responses:**

**GET /** - API information (root endpoint):

```json
{
  "api_name": "apigw-regional",
  "description": "Demo API with custom domain and wildcard certificate",
  "endpoints": [
    "GET / - API information and metadata",
    "GET /hello - Simple greeting message",
    "GET /status - Health check endpoint"
  ],
  "certificate": "*.group1.dev.example.com",
  "custom_domain": "web.group1.dev.example.com",
  "region": "ap-southeast-2",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**GET /hello** - Simple greeting:

```json
{
  "message": "Hello from Regional API Gateway!",
  "timestamp": "2024-01-15T10:30:00Z",
  "domain": "web.group1.dev.example.com"
}
```

**GET /status** - Health check:

```json
{
  "status": "healthy",
  "service": "Regional API Gateway Demo",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "region": "ap-southeast-2",
  "domain": "web.group1.dev.example.com"
}
```

## Configuration Details

### Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `domain_name` | The Route 53 hosted zone name | `dev.example.com` |
| `namespace` | Subdomain prefix for isolation | `group1` |
| `subdomain` | Specific API subdomain | `web`, `customer1`, `api` |

### Generated Resources

- **Custom Domain**: `{subdomain}.{namespace}.{domain_name}`
- **Wildcard Certificate**: `*.{namespace}.{domain_name}`
- **API Endpoints**:
  - `GET /` - API information and metadata (root endpoint)
  - `GET /hello` - Simple greeting message
  - `GET /status` - Health check endpoint

### Example Domain Patterns

With `domain_name = "dev.example.com"` and `namespace = "group1"`:

- `web.group1.dev.example.com` (subdomain = "web")
- `customer1.group1.dev.example.com` (subdomain = "customer1")
- `api.group1.dev.example.com` (subdomain = "api")

## Outputs

The configuration provides several useful outputs:

- `custom_domain_url`: The HTTPS URL for your custom domain
- `api_gateway_invoke_url`: The direct API Gateway invoke URL
- `test_curl_command`: Ready-to-use curl command for testing the /hello endpoint
- `test_commands`: All available test commands for each endpoint

## Multi-Tenant Usage

This configuration supports multiple deployments by changing the `subdomain` variable:

```bash
# Deploy for customer 1
terraform apply -var="subdomain=customer1"

# Deploy for customer 2
terraform apply -var="subdomain=customer2"

# Deploy for web frontend
terraform apply -var="subdomain=web"
```

Each deployment creates a separate custom domain but uses the same wildcard certificate and hosted zone.

## Security Features

### IP-Based Access Control

The configuration includes IP-based access control:

- **Automatic Detection**: Gets your current public IP from `https://checkip.amazonaws.com/`
- **Single IP Access**: Only your current public IP can access the API Gateway
- **Dynamic Updates**: Run `terraform apply` again if your IP changes
- **403 Forbidden**: Other IPs get access denied

### Resource Policy

The API Gateway uses a resource policy with IP-based conditions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:ap-southeast-2:ACCOUNT:API-ID/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "YOUR_IP_ADDRESS/32"
        }
      }
    }
  ]
}
```

## Cleanup

To remove the infrastructure:

```bash
terraform destroy
```

**Note**: This will delete the ACM certificate and all associated resources.

## Troubleshooting

### Certificate Validation Issues

If certificate validation fails:

1. Check that the Route 53 hosted zone exists and is accessible
2. Verify DNS propagation (can take up to 24 hours)
3. Ensure the wildcard domain pattern is correct

### API Gateway Custom Domain Issues

If the custom domain doesn't work:

1. Verify the ACM certificate is validated
2. Check that the base path mapping is created
3. Ensure the Route 53 A record is pointing to the correct API Gateway domain

### DNS Resolution Issues

If DNS doesn't resolve:

1. Check Route 53 record configuration
2. Verify the hosted zone name servers are configured correctly
3. Test with `dig` or `nslookup` commands
4. Wait for DNS propagation (can take up to 24 hours)

### IP Access Control Issues

If you get "Forbidden" errors:

1. Check your current public IP: `curl -s https://checkip.amazonaws.com/`
2. Run `terraform apply` to update the policy with your current IP
3. Verify the policy is applied: `terraform state show aws_api_gateway_rest_api_policy.this`

### SSL Certificate Issues

If you get SSL errors:

1. Verify the ACM certificate is validated
2. Check that the certificate covers the correct domain pattern
3. Ensure the custom domain is properly configured
4. Test with `-k` flag: `curl -k https://your-domain.com/`
