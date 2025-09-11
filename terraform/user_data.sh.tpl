Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/user-data.log
}

log "Starting user data script execution"

# Environment Variables (passed from Terraform)
export APP_PORT="${app_port}"
export ENVIRONMENT="${environment}"
export GIT_REPO="${git_repo_url}"
export GIT_BRANCH="${git_branch}"
export DATABASE_URL="${database_url}"
export SECRET_KEY_BASE="${secret_key_base}"
export PHX_HOST="${domain_name}"
export BEARER_TOKEN="${bearer_token}"
export WHITELISTED_DOMAINS="${whitelisted_domains}"
export GOOGLE_CREDENTIALS_JSON="${google_credentials_json}"
export POOL_SIZE="${pool_size}"

# Install git first if not present (Ubuntu)
if ! dpkg -s git >/dev/null 2>&1; then
    log "Installing git (Ubuntu)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git ca-certificates curl
fi

# Create setup directory
SETUP_DIR="/tmp/dbservice-setup"
mkdir -p "$SETUP_DIR"
cd "$SETUP_DIR"

# Clone repository to get setup script
log "Cloning repository to get setup script"
if [ -d "dbservice" ]; then
    rm -rf dbservice
fi

git clone -b "$GIT_BRANCH" "$GIT_REPO" dbservice

# Check if setup script exists
SETUP_SCRIPT="$SETUP_DIR/dbservice/scripts/setup.sh"
if [ ! -f "$SETUP_SCRIPT" ]; then
    log "ERROR: Setup script not found at $SETUP_SCRIPT"
    exit 1
fi

# Make setup script executable
chmod +x "$SETUP_SCRIPT"

# Export all environment variables for the setup script
log "Executing main setup script"
export SETUP_DIR="$SETUP_DIR"

# Execute the setup script
"$SETUP_SCRIPT"

# Clean up setup directory
cd /
rm -rf "$SETUP_DIR"

log "User data script execution completed successfully"

--//