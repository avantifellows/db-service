# db-service infra runbook (ECS Fargate)

Step-by-step manual procedures for **applying**, **deploying**, **cutting over DNS**,
and **destroying** the db-service staging/prod infrastructure. See `README.md` for
the architecture overview; this doc is the operational how-to.

- **Region:** `ap-south-1` · **AWS account:** `111766607077`
- **State bucket:** `111766607077-dbservice-test-terraform-state`
  (keys: `dbservice/staging/terraform.tfstate`, `dbservice/prod/terraform.tfstate`)
- **URLs:** staging → `staging-db.avantifellows.org` · prod → `db.avantifellows.org`
- The same `terraform/` folder manages **both** envs; the difference is the
  backend state key (at `init`) + the `envs/<env>.tfvars` file (at `plan`/`apply`).
  Always use the `Makefile` wrappers so those two stay paired.

---

## 1. Prerequisites (one-time)

**Tools:** `terraform` (>= 1.5), `awscli`, `jq`, `gh` (GitHub CLI), and an AWS
profile with access to account `111766607077`.

```bash
export AWS_PROFILE=<your-aws-profile>   # e.g. amanb
export AWS_REGION=ap-south-1
```

**Secrets file** — sensitive Terraform inputs are NEVER committed; they live in a
local mode-600 env file and are sourced before running Terraform:

```bash
# ~/.terraform-dbservice-staging.env   (chmod 600)
export TF_VAR_database_url="ecto://<user>:<pass>@<staging-db-host>/<db>"
export TF_VAR_secret_key_base="..."
export TF_VAR_bearer_token="..."
export TF_VAR_google_credentials_json='{ ... service account json ... }'
export TF_VAR_dashboard_user="..."
export TF_VAR_dashboard_pass="..."
export TF_VAR_cloudflare_api_token="..."   # scoped token, see 1a below
```

Load it in your shell before any Terraform command:

```bash
set -a; source ~/.terraform-dbservice-staging.env; set +a
```

(Prod uses the same values except its own `TF_VAR_database_url` / `secret_key_base` /
etc. — keep a separate `~/.terraform-dbservice-prod.env`. The Cloudflare token is
the same for both, since it's the same zone.)

### 1a. Cloudflare scoped API token
Terraform authenticates to Cloudflare with a **scoped** token (not the account
Global API Key). To create one:
1. Cloudflare dashboard → **My Profile → API Tokens → Create Token**.
2. Template **"Edit zone DNS"**.
3. **Zone Resources → Include → Specific zone → `avantifellows.org`**.
4. Create, copy the token, put it in the env file as `TF_VAR_cloudflare_api_token`.
5. Verify: `curl -s https://api.cloudflare.com/client/v4/user/tokens/verify -H "Authorization: Bearer <token>" | jq .result.status` → `"active"`.

---

## 2. Apply (create / update) — STAGING

```bash
set -a; source ~/.terraform-dbservice-staging.env; set +a
export AWS_PROFILE=<profile> AWS_REGION=ap-south-1

make tf-init-staging     # init backend against the staging state key
make tf-plan-staging     # review the plan
make tf-apply-staging    # apply
```

> The staging `plan`/`apply` targets pass `-var=create_ci_user=true`. The shared
> CI deploy IAM user lives in **staging** state and has `prevent_destroy` — leaving
> the flag off would try to delete it and fail.

Raw equivalent (if not using the Makefile):
```bash
cd terraform
terraform init -reconfigure -backend-config="key=dbservice/staging/terraform.tfstate"
terraform plan  -var-file=envs/staging.tfvars -var=create_ci_user=true
terraform apply -var-file=envs/staging.tfvars -var=create_ci_user=true
```

**First-ever apply only:** ECR is empty, so the ECS service is unhealthy (503)
until the first image is pushed — that's expected. Run a deploy (section 4) to
populate ECR, then it goes healthy.

Then verify:
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://staging-db.avantifellows.org/api/health   # expect 200
```

---

## 3. Apply — PRODUCTION

Same as staging but with the prod state key + tfvars + secrets file:
```bash
set -a; source ~/.terraform-dbservice-prod.env; set +a
make tf-init-prod
make tf-plan-prod
make tf-apply-prod
```
Notes:
- Prod targets do **not** set `create_ci_user` — the CI user is created once, in
  staging state, and shared. Keep it `false` for prod.
- Prod listener rule priority is `100`, staging is `200` (both on the shared ALB).

---

## 4. Deploy the application (image + migrations)

Terraform provisions infra; it does **not** build/ship the app. That's the ECS
deploy workflows (GitHub Actions), which build the image, push to ECR, run
migrations as a one-off Fargate task, roll the service, and smoke-check.

- **Staging:** auto-runs on every **PR → `main`**. Manual:
  ```bash
  gh workflow run staging_deploy_ecs.yml --repo avantifellows/db-service -f ref=main
  ```
- **Production:** only the **`release`** branch is allowed. Manual:
  ```bash
  gh workflow run production_deploy_ecs.yml --repo avantifellows/db-service -f ref=release
  ```

The deploy needs the `DB_SERVICE_AWS_ACCESS_KEY_ID` / `DB_SERVICE_AWS_SECRET_ACCESS_KEY`
repo secrets (the CI user's key). If those are missing/stale, the deploy fails at
the AWS-credentials step — see section 7.

> Note: the ECS service has `lifecycle { ignore_changes = [task_definition] }`, so
> a task-size/env change in Terraform only takes effect once a **deploy** runs
> (the workflow renders a new task def from the latest revision).

---

## 5. DNS cutover (point a host at this infra)

The host is set by `domain_prefix` in `envs/<env>.tfvars` (`staging-db` → prod host
is `db`). Terraform manages that Cloudflare record. If the target hostname **already
exists** in Cloudflare (e.g. pointing at an old server), Terraform can't create its
record until the existing one is removed:

```bash
set -a; source ~/.terraform-dbservice-staging.env; set +a
ZONE=7f1dbe8fd33ebb03cbde59464bbcc042
# find the existing record id
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?name=<host>.avantifellows.org" \
  -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" | jq '.result[] | {id,type,content,proxied}'
# delete it
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/<id>" \
  -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" | jq .success
```

Then:
1. Set `domain_prefix` + `whitelisted_domains` in the tfvars to the new host.
2. `make tf-apply-<env>` — recreates the Cloudflare record (CNAME → ALB), moves the
   ALB listener-rule host condition, and registers a new task def with the new
   `PHX_HOST` / `WHITELISTED_DOMAINS`.
3. Run a **deploy** (section 4) so the running task picks up the new host (else the
   app's domain whitelist rejects it with 403).
4. Verify against public DNS (your laptop may cache the old record for ~5 min):
   ```bash
   dig @1.1.1.1 +short <host>.avantifellows.org
   curl -s -o /dev/null -w "%{http_code}\n" https://<host>.avantifellows.org/api/health
   ```
5. If you also changed the smoke-check target, update `SERVICE_HOST` in the deploy
   workflow to match.

---

## 6. Destroy

⚠️ Destroy is disruptive and has guards. Read all steps before starting.

**Consequences to know:**
- **ECR** has `force_delete = true` → all pushed images are deleted. After a later
  re-apply the service is unhealthy until you redeploy.
- The **CI user** is shared and backs the GitHub deploy secrets — see section 7.
- The Cloudflare record is deleted → the host stops resolving.

**Steps (staging):**
```bash
set -a; source ~/.terraform-dbservice-staging.env; set +a
export AWS_PROFILE=<profile> AWS_REGION=ap-south-1
make tf-init-staging
```

1. **Empty the S3 CSV bucket** (it has no `force_destroy`, so a non-empty bucket
   blocks destroy):
   ```bash
   aws s3 rm s3://db-service-staging-csv-imports --recursive --region ap-south-1
   ```
2. **Disable `prevent_destroy` on the CI user** — in `iam.tf`, temporarily set
   `prevent_destroy = false` in the `aws_iam_user.ci` lifecycle block (otherwise
   destroy aborts). Only needed if `create_ci_user=true` for this env (staging).
3. **Destroy:**
   ```bash
   terraform destroy -var-file=envs/staging.tfvars -var=create_ci_user=true
   ```
   (Prod: `terraform destroy -var-file=envs/prod.tfvars`, no create_ci_user.)
4. **Restore** `prevent_destroy = true` in `iam.tf` afterwards.

To destroy **without** removing the shared CI user (e.g. tearing down just the
compute), exclude it: add `-target` for the resources you want, or keep
`create_ci_user=true` and it stays (count-based, so a plain destroy removes it —
use targeting to keep it).

---

## 7. GitHub deploy secrets (CI user key)

The CI user's access key is created by the **staging apply** (`create_ci_user=true`)
and stored as repo secrets. If the CI user is (re)created, its key changes and the
secrets must be re-set, or deploys fail at the AWS-credentials step:

```bash
cd terraform
gh secret set DB_SERVICE_AWS_ACCESS_KEY_ID --repo avantifellows/db-service \
  --body "$(terraform output -raw ci_access_key_id)"
terraform output -raw ci_secret_access_key \
  | gh secret set DB_SERVICE_AWS_SECRET_ACCESS_KEY --repo avantifellows/db-service
```

---

## 8. Gotchas / lessons learned

- **`ignore_changes = [task_definition]`** — Terraform won't move the service onto a
  new task def; only a deploy does. Apply Terraform *and* run a deploy when you
  change task size / env.
- **Health checks:** `/api/health` is a cheap liveness probe (no DB); `/api/health/ready`
  checks the DB. The ALB uses `/api/health`.
- **DB connections:** each task opens its own pool (`POOL_SIZE`). Task count ×
  `POOL_SIZE` must stay under the RDS `max_connections`. Watch for leaked/idle
  connections (orphaned app processes) exhausting a small instance.
- **Autoscaling is reactive (~2–3 min).** For load tests, pre-scale `min_capacity`
  rather than relying on target-tracking to catch a steep ramp.
- **Local DNS cache** after a cutover: flush with
  `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`, and restart
  browser/Postman. Public resolvers (1.1.1.1 / 8.8.8.8) reflect the truth.
