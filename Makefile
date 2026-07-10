# Terraform wrappers — the same terraform/ folder manages BOTH staging and prod,
# distinguished only by (a) the backend state key passed at init and (b) the
# tfvars file passed at plan/apply. `terraform init -backend-config=...` is
# sticky in the local .terraform/ dir, so it's easy to end up initialized
# against one env's state and then plan/apply the other env's values against it.
#
# These targets always pair the correct backend key with the correct tfvars, and
# always `-reconfigure` on init so switching envs can't reuse a stale backend.
#
# Secrets are still supplied via TF_VAR_* env vars (see README) — e.g.:
#   source ~/.terraform-dbservice-staging.env && make tf-plan-staging

TF := terraform -chdir=terraform

.PHONY: tf-init-staging tf-plan-staging tf-apply-staging \
        tf-init-prod tf-plan-prod tf-apply-prod

# ---- Staging ----------------------------------------------------------------
tf-init-staging:
	$(TF) init -reconfigure -backend-config="key=dbservice/staging/terraform.tfstate"

tf-plan-staging: tf-init-staging
	$(TF) plan -var-file=envs/staging.tfvars -var=create_ci_user=true

# create_ci_user=true: the shared CI IAM user lives in STAGING state and has
# prevent_destroy — applying without it would try to delete the user CI relies on.
tf-apply-staging: tf-init-staging
	$(TF) apply -var-file=envs/staging.tfvars -var=create_ci_user=true

# ---- Production -------------------------------------------------------------
tf-init-prod:
	$(TF) init -reconfigure -backend-config="key=dbservice/prod/terraform.tfstate"

tf-plan-prod: tf-init-prod
	$(TF) plan -var-file=envs/prod.tfvars

tf-apply-prod: tf-init-prod
	$(TF) apply -var-file=envs/prod.tfvars
