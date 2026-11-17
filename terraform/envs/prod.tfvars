environment = "prod"
# Parallel-host validation: ECS serves prod-db.avantifellows.org while the
# legacy EC2 box keeps serving db.avantifellows.org. Flip this to "db" only at
# the real cutover, once prod-db has been validated end-to-end.
domain_prefix          = "prod-db"
listener_rule_priority = 100

# WHITELISTED_DOMAINS — comma-separated host list enforced by DomainWhitelistPlug.
# Mirror what's currently set in the EC2 .env for production; adjust as needed.
whitelisted_domains = "prod-db.avantifellows.org"

# Capacity/scaling — mirrors staging, which was tuned after the 2026-06-21 load
# test (1000 users / ~174 RPS) saturated a single 0.5-vCPU task: CPU pinned
# ~100%, /api/health timed out, the lone task got recycled, and with min=1 that
# left 0 healthy targets → 502/503/504 bursts. Prod carries more traffic than
# staging, so it must not go out on the smaller default shape.
cpu                    = 1024 # 1 vCPU (was the 512 default)
memory                 = 2048 # 2 GiB (was the 1024 default)
min_capacity           = 2    # always keep a healthy target during recycle/deploy
max_capacity           = 4
target_cpu_utilization = 60 # scale out before tasks fall over

# Sensitive variables (database_url, secret_key_base, bearer_token,
# google_credentials_json, dashboard_user, dashboard_pass) MUST be supplied
# via TF_VAR_* env vars. See ../README.md.
