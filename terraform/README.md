# db-service Terraform

Infrastructure for the ECS Fargate deployment of `db-service`. Same code,
two environments — staging and prod each get their own state file.

## Layout

```
terraform/
├── main.tf            # AWS provider + default tags
├── backend.tf         # S3 backend (state bucket fixed; key supplied at init)
├── variables.tf       # All inputs
├── outputs.tf         # Service name, log group, ECR URL, etc.
├── ecr.tf             # Container registry
├── ecs.tf             # Cluster, task definition, service, auto-scaling
├── alb.tf             # Target group + listener rule on existing ALB
├── dns.tf             # Route53 A-alias to the ALB
├── security.tf        # Security group for tasks
├── iam.tf             # Execution role, task role, optional CI user
├── logs.tf            # CloudWatch Logs group
├── s3.tf              # CSV imports bucket
└── envs/
    ├── staging.tfvars # Non-sensitive staging values
    └── prod.tfvars    # Non-sensitive prod values
```

## Per-environment isolation

Every resource is created with an `{environment}` suffix (e.g. `db-service-staging`,
`db-service-prod`). The two environments share **nothing** at the AWS level except:

- The existing shared ALB (`af-load-balancer`) — we add a listener rule, not a new ALB.
- The Route53 zone (`avantifellows.org`) — we add a record, not a new zone.
- The wildcard ACM cert — already attached to the ALB.
- The Terraform state bucket (`111766607077-dbservice-test-terraform-state`) — separate
  state files keyed by `dbservice/{env}/terraform.tfstate`.

The CI deploy IAM user (`db-service-ci-deploy`) is genuinely shared. Set
`create_ci_user = true` on **exactly one** environment's apply (recommended: staging,
once, then flip back to false). Both `staging.tfvars` and `prod.tfvars` ship with it
set to `false`.

## Sensitive variables

Never committed to git. Pass via `TF_VAR_*` env vars at apply time. In CI these
come from GitHub Secrets:

| Variable | Source |
|---|---|
| `TF_VAR_database_url` | `STAGING_DATABASE_URL` / `PRODUCTION_DATABASE_URL` |
| `TF_VAR_secret_key_base` | `STAGING_SECRET_KEY_BASE` / `PRODUCTION_SECRET_KEY_BASE` |
| `TF_VAR_bearer_token` | `STAGING_BEARER_TOKEN` / `PRODUCTION_BEARER_TOKEN` |
| `TF_VAR_google_credentials_json` | `STAGING_GOOGLE_CREDENTIALS_JSON` / `PRODUCTION_GOOGLE_CREDENTIALS_JSON` |
| `TF_VAR_dashboard_user` | `STAGING_DASHBOARD_USER` / `PRODUCTION_DASHBOARD_USER` |
| `TF_VAR_dashboard_pass` | `STAGING_DASHBOARD_PASS` / `PRODUCTION_DASHBOARD_PASS` |

## Apply

```sh
cd terraform/

# --- Staging ---
terraform init -backend-config="key=dbservice/staging/terraform.tfstate"
terraform plan  -var-file=envs/staging.tfvars
terraform apply -var-file=envs/staging.tfvars

# --- Production ---
# (re-init switches the state file)
terraform init -reconfigure -backend-config="key=dbservice/prod/terraform.tfstate"
terraform plan  -var-file=envs/prod.tfvars
terraform apply -var-file=envs/prod.tfvars
```

## First apply ordering

Order doesn't matter between environments — no shared TF resources to gate on.

The first apply in each environment creates an ECR repo and an ECS service that
references `image_tag = "latest"`. Until the Phase 4 CI pipeline pushes the first
image, ECS will retry pulls and the target group will report unhealthy. The ALB
listener rule + Route53 record will exist and resolve, but `db.avantifellows.org`
will return 503 until a real image lands. This is expected.

Subsequent deploys are driven by the GitHub Actions workflow registering a new task
definition revision (with the new image tag) and updating the service — Terraform
doesn't run on every deploy.
