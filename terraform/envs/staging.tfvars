environment = "staging"
# "staging-db" collides with the existing EC2 staging host; use a distinct name.
domain_prefix          = "staging-database"
listener_rule_priority = 200

# WHITELISTED_DOMAINS — comma-separated host list enforced by DomainWhitelistPlug.
# Mirror what's currently set in the EC2 .env for staging; adjust as needed.
whitelisted_domains = "staging-database.avantifellows.org,localhost"

# Capacity/scaling — tuned after the 2026-06-21 load test (1000 users / ~174 RPS)
# saturated a single 0.5-vCPU task: CPU pinned ~100%, /api/health timed out, the
# lone task got recycled, and with min=1 that left 0 healthy targets → 502/503/504
# bursts. min_capacity=2 removes the single-task outage window; the bigger task
# raises the per-task ceiling; target=60 scales out sooner.
cpu                    = 1024 # 1 vCPU (was 512)
memory                 = 2048 # 2 GiB (was 1024)
min_capacity           = 2    # was 1 — always keep a healthy target during recycle/deploy
max_capacity           = 4    # was 3
target_cpu_utilization = 60   # was 70 — scale out before tasks fall over

# Sensitive variables (database_url, secret_key_base, bearer_token,
# google_credentials_json, dashboard_user, dashboard_pass) MUST be supplied
# via TF_VAR_* env vars. See ../README.md.
