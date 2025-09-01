#!/bin/bash
set -e
set -o pipefail
set -u

# Ensure HOME is set for non-interactive root shell (required by asdf)
export HOME="/root"

# Comprehensive EC2 Setup Script for DBService
# This script contains all the deployment logic moved from user_data.sh.tpl

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/setup.log
}

log "Starting comprehensive setup script execution"

# Validate required environment variables
REQUIRED_VARS=(
    "APP_PORT" "ENVIRONMENT" "GIT_REPO" "GIT_BRANCH" 
    "DATABASE_URL" "SECRET_KEY_BASE" "PHX_HOST" 
    "BEARER_TOKEN" "WHITELISTED_DOMAINS" "GOOGLE_CREDENTIALS_JSON" "POOL_SIZE"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

log "All required environment variables are set"

# System Performance Optimizations (idempotent)
log "Configuring system performance optimizations"

# Check if limits are already configured
if ! grep -q "soft nofile 65536" /etc/security/limits.conf; then
    log "Adding file descriptor limits to limits.conf"
    echo "* soft nofile 65536" >> /etc/security/limits.conf
    echo "* hard nofile 65536" >> /etc/security/limits.conf
    echo "* soft nproc 32768" >> /etc/security/limits.conf
    echo "* hard nproc 32768" >> /etc/security/limits.conf
else
    log "System limits already configured, skipping"
fi

# Check if sysctl parameters are already configured
if ! grep -q "net.core.somaxconn = 32768" /etc/sysctl.conf; then
    log "Adding network performance parameters to sysctl.conf"
    cat >> /etc/sysctl.conf << EOF
# Network performance
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
net.core.netdev_max_backlog = 32768

# File system performance
fs.file-max = 2097152
EOF
    sysctl -p
else
    log "Sysctl parameters already configured, skipping"
fi

# Package installations (idempotent)
log "Installing required packages"

export DEBIAN_FRONTEND=noninteractive

# Ensure apt cache is up to date
apt-get update -y

# Check if packages are already installed
if ! dpkg -s nginx >/dev/null 2>&1; then
    log "Installing nginx (Ubuntu)"
    apt-get install -y nginx
else
    log "Nginx already installed, skipping"
fi

if ! dpkg -s git >/dev/null 2>&1; then
    log "Installing git (Ubuntu)"
    apt-get install -y git
else
    log "Git already installed, skipping"
fi

if ! dpkg -s htop >/dev/null 2>&1; then
    log "Installing additional packages (Ubuntu)"
    apt-get install -y htop ca-certificates curl unzip tar
else
    log "Additional packages already installed, skipping"
fi

# Install development tools (idempotent)
log "Installing development tools"
if ! dpkg -s build-essential >/dev/null 2>&1; then
    log "Installing build-essential"
    apt-get install -y build-essential
else
    log "build-essential already installed, skipping"
fi

# Install development dependencies for Erlang/Elixir builds
if ! dpkg -s libssl-dev >/dev/null 2>&1 || ! dpkg -s libncurses5-dev >/dev/null 2>&1 || ! dpkg -s zlib1g-dev >/dev/null 2>&1; then
    log "Installing development dependencies for Erlang/Elixir"
    apt-get install -y \
        autoconf m4 libncurses5-dev libncursesw5-dev libssl-dev \
        libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
        libssh-dev unixodbc-dev xsltproc fop libxml2-utils libreadline-dev \
        libffi-dev zlib1g-dev
else
    log "Development dependencies already installed, skipping"
fi

# Install ASDF version manager (idempotent)
log "Setting up ASDF version manager"
if [ ! -d /root/.asdf ]; then
    log "Installing ASDF version manager"
    git clone https://github.com/asdf-vm/asdf.git /root/.asdf --branch v0.14.0
    
    # Add to bashrc only if not already present
    if ! grep -q '.asdf/asdf.sh' ~/.bashrc; then
        echo '. /root/.asdf/asdf.sh' >> ~/.bashrc
        echo '. /root/.asdf/completions/asdf.bash' >> ~/.bashrc
    fi
else
    log "ASDF already installed, skipping"
fi

export PATH="/root/.asdf/bin:$PATH"
source /root/.asdf/asdf.sh

# Ensure ASDF shims are in PATH for current session
export PATH="/root/.asdf/shims:$PATH"
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac --without-wx"
export KERL_BUILD_DOCS=no

# Install Erlang and Elixir plugins (idempotent)
log "Setting up Erlang and Elixir plugins"
if ! asdf plugin list | grep -q erlang; then
    log "Adding Erlang plugin"
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
    # Update plugin to ensure we have latest version lists
    log "Updating Erlang plugin to get latest versions"
    asdf plugin update erlang || log "Warning: Failed to update Erlang plugin, continuing anyway"
else
    log "Erlang plugin already installed, updating to get latest versions"
    asdf plugin update erlang || log "Warning: Failed to update Erlang plugin, continuing anyway"
fi

if ! asdf plugin list | grep -q elixir; then
    log "Adding Elixir plugin"
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
    # Update plugin to ensure we have latest version lists
    log "Updating Elixir plugin to get latest versions"
    asdf plugin update elixir || log "Warning: Failed to update Elixir plugin, continuing anyway"
else
    log "Elixir plugin already installed, updating to get latest versions"
    asdf plugin update elixir || log "Warning: Failed to update Elixir plugin, continuing anyway"
fi

# Install specific versions (idempotent with retry logic)
log "Installing Erlang and Elixir versions"
log "NOTE: This is typically the longest part of the setup (15-25 minutes total)"
log "Erlang compilation can take 10-20 minutes, Elixir takes 2-5 minutes"

# Function to retry installation with backoff
retry_install() {
    local package=$1
    local version=$2
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Installing $package $version (attempt $attempt/$max_attempts)"
        
        # Capture asdf install output and log it
        log "Starting $package $version installation... (this may take 10-20 minutes for Erlang, 2-5 minutes for Elixir)"
        log "Progress will be logged to /var/log/setup.log - you can monitor with: tail -f /var/log/setup.log"
        if asdf install $package $version 2>&1 | tee -a /var/log/setup.log; then
            log "$package $version installation completed successfully"
            asdf global $package $version
            log "Set $package $version as global version"
            return 0
        else
            log "Installation attempt $attempt failed for $package $version"
            if [ $attempt -lt $max_attempts ]; then
                local wait_time=$((attempt * 30))
                log "Waiting $wait_time seconds before retry (attempt $((attempt + 1))/$max_attempts)..."
                
                # Countdown timer for better visibility in logs
                local remaining=$wait_time
                while [ $remaining -gt 0 ]; do
                    if [ $((remaining % 10)) -eq 0 ] || [ $remaining -le 5 ]; then
                        log "Retry countdown: $remaining seconds remaining..."
                    fi
                    sleep 1
                    remaining=$((remaining - 1))
                done
                
                # Clean up failed installation
                log "Cleaning up failed $package $version installation..."
                asdf uninstall $package $version 2>&1 | tee -a /var/log/setup.log || true
                log "Cleanup completed, starting retry..."
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Failed to install $package $version after $max_attempts attempts"
    return 1
}

ERLANG_VERSION="26.2.5"

# Install Erlang with retry logic
if ! asdf list erlang | grep -q "$ERLANG_VERSION"; then
    if ! retry_install erlang $ERLANG_VERSION; then
        log "CRITICAL ERROR: Erlang installation failed after retries. Attempting alternative installation..."
        
        # Alternative: Try updating the plugin and retry once more
        log "Updating asdf-erlang plugin to get latest version..."
        if asdf plugin update erlang 2>&1 | tee -a /var/log/setup.log; then
            log "Plugin update successful, attempting final Erlang installation..."
        else
            log "Plugin update failed, but continuing with final installation attempt..."
        fi
        
        log "Final attempt to install Erlang $ERLANG_VERSION..."
        if asdf install erlang $ERLANG_VERSION 2>&1 | tee -a /var/log/setup.log; then
            log "Final Erlang installation attempt succeeded"
            asdf global erlang $ERLANG_VERSION
            log "Set Erlang $ERLANG_VERSION as global version"
        else
            log "FATAL: Unable to install Erlang after all attempts. Deployment cannot continue."
            log "Check /var/log/setup.log for detailed error messages"
            exit 1
        fi
    fi
else
    log "Erlang $ERLANG_VERSION already installed, setting as global"
    asdf global erlang $ERLANG_VERSION
    log "Confirmed Erlang $ERLANG_VERSION set as global version"
fi

log "Verifying Erlang installation..."
# Ensure ASDF environment is properly loaded
source /root/.asdf/asdf.sh
asdf reshim erlang || true
if /root/.asdf/installs/erlang/$ERLANG_VERSION/bin/erl -version 2>&1 | tee -a /var/log/setup.log; then
    log "Erlang installation verification successful"
else
    log "ERROR: Erlang installation verification failed"
    exit 1
fi

ELIXIR_VERSION="1.18.4"

# Install Elixir with retry logic
if ! asdf list elixir | grep -q "$ELIXIR_VERSION"; then
    if ! retry_install elixir $ELIXIR_VERSION; then
        log "CRITICAL ERROR: Elixir installation failed after retries. Attempting alternative installation..."
        
        # Alternative: Try updating the plugin and retry once more
        log "Updating asdf-elixir plugin to get latest version..."
        if asdf plugin update elixir 2>&1 | tee -a /var/log/setup.log; then
            log "Plugin update successful, attempting final Elixir installation..."
        else
            log "Plugin update failed, but continuing with final installation attempt..."
        fi
        
        log "Final attempt to install Elixir $ELIXIR_VERSION..."
        if asdf install elixir $ELIXIR_VERSION 2>&1 | tee -a /var/log/setup.log; then
            log "Final Elixir installation attempt succeeded"
            asdf global elixir $ELIXIR_VERSION
            log "Set Elixir $ELIXIR_VERSION as global version"
        else
            log "FATAL: Unable to install Elixir after all attempts. Deployment cannot continue."
            log "Check /var/log/setup.log for detailed error messages"
            exit 1
        fi
    fi
else
    log "Elixir $ELIXIR_VERSION already installed, setting as global"
    asdf global elixir $ELIXIR_VERSION
    log "Confirmed Elixir $ELIXIR_VERSION set as global version"
fi

log "Verifying Elixir installation..."
source /root/.asdf/asdf.sh
asdf reshim elixir || true
if /root/.asdf/installs/elixir/$ELIXIR_VERSION/bin/elixir --version 2>&1 | tee -a /var/log/setup.log; then
    log "Elixir installation verification successful"
else
    log "ERROR: Elixir installation verification failed"
    exit 1
fi

# Make sure asdf binaries are available globally (idempotent)
log "Creating global symlinks for ASDF binaries"
if [ ! -L /usr/local/bin/erl ]; then
    ln -sf /root/.asdf/shims/erl /usr/local/bin/erl
fi
if [ ! -L /usr/local/bin/elixir ]; then
    ln -sf /root/.asdf/shims/elixir /usr/local/bin/elixir
fi
if [ ! -L /usr/local/bin/mix ]; then
    ln -sf /root/.asdf/shims/mix /usr/local/bin/mix
fi

# Configure Nginx (idempotent)
log "Configuring Nginx"

# Check if custom nginx.conf already exists with our configuration
if ! grep -q "worker_rlimit_nofile 65536" /etc/nginx/nginx.conf 2>/dev/null; then
    log "Creating custom nginx.conf"
    cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65536;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF
else
    log "Custom nginx.conf already exists, skipping"
fi

# Check if dbservice configuration already exists
if [ ! -f /etc/nginx/conf.d/dbservice.conf ] || ! grep -q "upstream phoenix" /etc/nginx/conf.d/dbservice.conf; then
    log "Creating dbservice nginx configuration"
    cat > /etc/nginx/conf.d/dbservice.conf << EOF
upstream phoenix {
    server 127.0.0.1:$APP_PORT max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    
    client_max_body_size 50M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    location / {
        proxy_pass http://phoenix;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }
}
EOF
else
    log "Dbservice nginx configuration already exists, updating port if needed"
    # Update the port in existing config if it differs
    sed -i "s/server 127.0.0.1:[0-9]*/server 127.0.0.1:$APP_PORT/" /etc/nginx/conf.d/dbservice.conf
fi

# Enable and start nginx (idempotent)
log "Starting nginx service"
if ! systemctl is-enabled nginx >/dev/null 2>&1; then
    systemctl enable nginx
fi

if ! systemctl is-active nginx >/dev/null 2>&1; then
    systemctl start nginx
else
    # Reload nginx to pick up any configuration changes
    systemctl reload nginx || systemctl restart nginx
fi

# Application deployment (idempotent)
log "Setting up application deployment"

mkdir -p /var/www/html
cd /var/www/html

APP_DIR="/var/www/html/dbservice-$ENVIRONMENT"

# Check if we need to clone/update the repository
NEED_CLONE=false
NEED_UPDATE=false

if [ ! -d "$APP_DIR" ]; then
    log "Application directory doesn't exist, will clone"
    NEED_CLONE=true
elif [ ! -d "$APP_DIR/.git" ]; then
    log "Application directory exists but is not a git repo, will re-clone"
    rm -rf "$APP_DIR"
    NEED_CLONE=true
else
    log "Checking if repository needs updating"
    cd "$APP_DIR"
    
    # Fetch latest changes
    git fetch origin "$GIT_BRANCH" 2>/dev/null || NEED_CLONE=true
    
    if [ "$NEED_CLONE" = false ]; then
        # Check if we're on the right branch and up to date
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
            log "Switching to branch $GIT_BRANCH"
            git checkout "$GIT_BRANCH" || NEED_CLONE=true
        fi
        
        if [ "$NEED_CLONE" = false ]; then
            LOCAL_COMMIT=$(git rev-parse HEAD)
            REMOTE_COMMIT=$(git rev-parse origin/$GIT_BRANCH)
            
            if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                log "Repository has updates, will pull latest changes"
                NEED_UPDATE=true
            else
                log "Repository is up to date"
            fi
        fi
    fi
fi

cd /var/www/html

if [ "$NEED_CLONE" = true ]; then
    log "Cloning repository"
    rm -rf "dbservice-$ENVIRONMENT"
    git clone -b "$GIT_BRANCH" "$GIT_REPO" "dbservice-$ENVIRONMENT"
    NEED_UPDATE=true
elif [ "$NEED_UPDATE" = true ]; then
    log "Updating repository"
    cd "$APP_DIR"
    git pull origin "$GIT_BRANCH"
fi

cd "$APP_DIR"

# Update credentials and environment configuration
log "Updating application configuration"
echo "$GOOGLE_CREDENTIALS_JSON" | base64 -d > config/etl-flow-key.json

# Create/update environment configuration
cat > config/.env << EOF
DATABASE_URL=$DATABASE_URL
SECRET_KEY_BASE=$SECRET_KEY_BASE
PHX_HOST=$PHX_HOST
POOL_SIZE=$POOL_SIZE
PORT=$APP_PORT
BEARER_TOKEN=$BEARER_TOKEN
WHITELISTED_DOMAINS=$WHITELISTED_DOMAINS
PATH_TO_CREDENTIALS=/var/www/html/dbservice-$ENVIRONMENT/config/etl-flow-key.json
EOF

# Application will run as root, so no ownership change needed

# Only rebuild if we cloned or updated the repository
if [ "$NEED_CLONE" = true ] || [ "$NEED_UPDATE" = true ]; then
    log "Building application (dependencies changed)"
    log "NOTE: Application build process typically takes 5-15 minutes depending on dependencies"
    log "Major steps: Hex/Rebar setup -> Dependency fetch -> Compilation -> Assets -> Migrations"
    export MIX_ENV=prod
    
    # Ensure ASDF environment is available for mix commands
    source /root/.asdf/asdf.sh
    export PATH="/root/.asdf/shims:$PATH"
    
    cd /var/www/html/dbservice-$ENVIRONMENT
    
    log "Installing local Hex package manager..."
    mix local.hex --force
    log "Hex installation completed"
    
    log "Installing local Rebar build tool..."
    mix local.rebar --force
    log "Rebar installation completed"
    
    log "Fetching application dependencies... (this may take several minutes)"
    mix deps.get
    log "Dependencies fetch completed"
    
    log "Compiling application dependencies... (this may take several minutes)"
    mix deps.compile
    log "Dependencies compilation completed"
    
    log "Deploying frontend assets... (this may take a few minutes)"
    mix assets.deploy
    log "Assets deployment completed"
    
    log "Generating asset digests..."
    mix phx.digest
    log "Asset digest generation completed"
    
    log "Running database migrations... (checking for new migrations)"
    # Always run migrations (they're idempotent in Ecto)
    mix ecto.migrate
    log "Database migrations completed"
    
    log "Generating Swagger documentation..."
    mix phx.swagger.generate
    log "Swagger documentation generation completed"
    
    RESTART_SERVICE=true
else
    log "Application code unchanged, skipping build"
    # Still run migrations in case there are new ones
    export MIX_ENV=prod
    
    # Ensure ASDF environment is available for mix commands
    source /root/.asdf/asdf.sh
    export PATH="/root/.asdf/shims:$PATH"
    
    cd /var/www/html/dbservice-$ENVIRONMENT
    log "Running database migrations... (checking for new migrations)"
    mix ecto.migrate
    log "Database migrations completed"
    RESTART_SERVICE=false
fi

# Configure systemd service (idempotent)
log "Configuring systemd service"

SERVICE_FILE="/etc/systemd/system/dbservice.service"
SERVICE_NEEDS_UPDATE=false

# Check if service file exists and has correct configuration
if [ ! -f "$SERVICE_FILE" ] || ! grep -q "WorkingDirectory=/var/www/html/dbservice-$ENVIRONMENT" "$SERVICE_FILE"; then
    log "Creating/updating dbservice systemd service"
    SERVICE_NEEDS_UPDATE=true
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=DB Service Phoenix Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/var/www/html/dbservice-$ENVIRONMENT
Environment=MIX_ENV=prod
Environment=ERL_MAX_PORTS=32768
Environment=ERL_PROCESS_LIMIT=1048576
ExecStart=/usr/local/bin/mix phx.server
ExecReload=/bin/kill -USR1 \$MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dbservice
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

LimitNOFILE=65536
LimitNPROC=32768

[Install]
WantedBy=multi-user.target
EOF
else
    log "Dbservice systemd service already configured correctly"
fi

# Reload systemd if service file was updated
if [ "$SERVICE_NEEDS_UPDATE" = true ]; then
    systemctl daemon-reload
fi

# Enable service if not already enabled
if ! systemctl is-enabled dbservice >/dev/null 2>&1; then
    log "Enabling dbservice"
    systemctl enable dbservice
fi

# Start or restart service based on conditions
if ! systemctl is-active dbservice >/dev/null 2>&1; then
    log "Starting dbservice"
    systemctl start dbservice
elif [ "$RESTART_SERVICE" = true ] || [ "$SERVICE_NEEDS_UPDATE" = true ]; then
    log "Restarting dbservice (configuration or code changed)"
    systemctl restart dbservice
else
    log "Dbservice already running and no changes detected"
fi

# Install and configure CloudWatch agent (idempotent)
log "Setting up CloudWatch agent"

if ! dpkg -s amazon-cloudwatch-agent >/dev/null 2>&1; then
    log "Installing CloudWatch agent (Ubuntu)"
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64|arm64)
            ;;
        *)
            log "Unsupported architecture for CloudWatch agent: $ARCH"
            ARCH="amd64"
            ;;
    esac
    TMP_DEB="/tmp/amazon-cloudwatch-agent.deb"
    URL="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/${ARCH}/latest/amazon-cloudwatch-agent.deb"
    log "Downloading CloudWatch agent from $URL"
    curl -fsSL -o "$TMP_DEB" "$URL"
    log "Installing CloudWatch agent package"
    apt-get install -y "$TMP_DEB" || {
        log "Initial install failed, attempting to fix dependencies"
        apt-get install -f -y
        dpkg -i "$TMP_DEB"
    }
    rm -f "$TMP_DEB"
else
    log "CloudWatch agent already installed"
fi

CW_CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

# Check if CloudWatch configuration exists and is correct
if [ ! -f "$CW_CONFIG_FILE" ] || ! grep -q "$ENVIRONMENT" "$CW_CONFIG_FILE"; then
    log "Creating CloudWatch agent configuration"
    
    cat > "$CW_CONFIG_FILE" << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/nginx/access",
                        "log_stream_name": "{instance_id}-$ENVIRONMENT"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/nginx/error",
                        "log_stream_name": "{instance_id}-$ENVIRONMENT"
                    }
                ]
            }
        }
    }
}
EOF
    
    CW_CONFIG_UPDATED=true
else
    log "CloudWatch agent configuration already exists"
    CW_CONFIG_UPDATED=false
fi

# Enable and start CloudWatch agent
if ! systemctl is-enabled amazon-cloudwatch-agent >/dev/null 2>&1; then
    systemctl enable amazon-cloudwatch-agent
fi

if ! systemctl is-active amazon-cloudwatch-agent >/dev/null 2>&1; then
    log "Starting CloudWatch agent"
    systemctl start amazon-cloudwatch-agent
elif [ "$CW_CONFIG_UPDATED" = true ]; then
    log "Restarting CloudWatch agent (configuration updated)"
    systemctl restart amazon-cloudwatch-agent
else
    log "CloudWatch agent already running"
fi

log "Setup script execution completed successfully"
log "====================================================================================="
log "DEPLOYMENT SUMMARY:"
log "- Erlang 26.2.5 and Elixir 1.18.4 installed via ASDF"
log "- Nginx configured and running on port 80, proxying to application on port $APP_PORT"
log "- Application deployed to /var/www/html/dbservice-$ENVIRONMENT"
log "- Systemd service 'dbservice' configured and running"
log "- CloudWatch agent configured for log collection"
log "- Database migrations executed"
log "====================================================================================="
log "You can monitor the application with:"
log "  - Service status: systemctl status dbservice"
log "  - Application logs: journalctl -u dbservice -f"
log "  - Nginx logs: tail -f /var/log/nginx/access.log"
log "  - Setup logs: tail -f /var/log/setup.log"
log "====================================================================================="
