environment = "staging"
# "staging-db" collides with the existing EC2 staging host; use a distinct name.
domain_prefix          = "staging-database"
listener_rule_priority = 200

# WHITELISTED_DOMAINS — comma-separated host list enforced by DomainWhitelistPlug.
# Mirror what's currently set in the EC2 .env for staging; adjust as needed.
whitelisted_domains = "staging-database.avantifellows.org,localhost"

# Sensitive variables (database_url, secret_key_base, bearer_token,
# google_credentials_json, dashboard_user, dashboard_pass) MUST be supplied
# via TF_VAR_* env vars. See ../README.md.
