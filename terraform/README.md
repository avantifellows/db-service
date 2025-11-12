# DB Service Terraform Infrastructure

## Quick Start

1. **Bootstrap the backend** (one-time setup):
```bash
cd terraform/backend-bootstrap
terraform init
terraform apply
```

2. **Deploy infrastructure**:
```bash
cd terraform
terraform init -reconfigure
terraform plan -var-file="environments/staging.tfvars" -var="db_password=your-secure-password"
terraform apply -var-file="environments/staging.tfvars" -var="db_password=your-secure-password"
```

## Key Design Decisions

### Database URL Construction

**Problem**: Originally, the `database_url` was a variable in the tfvars files, but this creates a circular dependency - you need to know the RDS endpoint before RDS is created.

**Solution**: The `database_url` is now **constructed dynamically** from the RDS instance that Terraform creates:

```hcl
# In ec2.tf user_data template
database_url = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:5432/${var.db_name}"
```

This means:
- ✅ No circular dependency
- ✅ Always uses the correct RDS endpoint
- ✅ Password is still managed securely via variables
- ✅ Other DB settings (username, database name) are configurable

### Required Secrets

Only pass these via `-var` or GitHub Actions secrets:

| Secret | Staging | Production | Purpose |
|--------|---------|------------|---------|
| `db_password` | `STAGING_DB_PASSWORD` | `PRODUCTION_DB_PASSWORD` | RDS master password |
| `secret_key_base` | `STAGING_SECRET_KEY_BASE` | `PRODUCTION_SECRET_KEY_BASE` | Phoenix encryption |
| `bearer_token` | `STAGING_BEARER_TOKEN` | `PRODUCTION_BEARER_TOKEN` | API authentication |
| `cloudflare_api_token` | `CLOUDFLARE_API_TOKEN` | `CLOUDFLARE_API_TOKEN` | DNS management |

### Example Commands

**Staging deployment**:
```bash
terraform apply -var-file="environments/staging.tfvars" \
  -var="db_password=staging-secure-password" \
  -var="secret_key_base=base64-encoded-secret" \
  -var="bearer_token=api-bearer-token" \
  -var="cloudflare_api_token=cf-token"
```

**View the constructed database URL**:
```bash
terraform output database_url
```

## File Structure

```
terraform/
├── main.tf                    # Core data sources and locals
├── variables.tf               # All variable definitions
├── outputs.tf                 # Output values including constructed database_url
├── providers.tf               # AWS and Cloudflare provider setup
├── security-groups.tf         # Network security rules
├── iam.tf                     # IAM roles and policies
├── rds.tf                     # PostgreSQL database
├── alb.tf                     # Application Load Balancer
├── ec2.tf                     # Auto Scaling Group and Launch Template
├── cloudflare.tf              # DNS records and health checks
├── cloudwatch.tf              # Log groups and monitoring
├── user_data.sh.tpl           # EC2 initialization script
├── environments/
│   ├── staging.tfvars         # Staging configuration
│   └── production.tfvars      # Production configuration
└── backend-bootstrap/         # S3 + DynamoDB backend setup
    ├── backend.tf
    └── variables.tf
```
