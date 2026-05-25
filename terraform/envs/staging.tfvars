environment            = "staging"
domain_prefix          = "staging-db"
listener_rule_priority = 200

# WHITELISTED_DOMAINS — comma-separated host list enforced by DomainWhitelistPlug.
# Mirror what's currently set in the EC2 .env for staging; adjust as needed.
whitelisted_domains = "staging-db.avantifellows.org,localhost"

# Sensitive variables (database_url, secret_key_base, bearer_token,
# google_credentials_json, dashboard_user, dashboard_pass) MUST be supplied
# via TF_VAR_* env vars. See ../README.md.
