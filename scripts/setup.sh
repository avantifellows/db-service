#!/bin/bash
set -e

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

# Check if packages are already installed
if ! rpm -q nginx >/dev/null 2>&1; then
    log "Installing nginx"
    yum update -y
    yum install -y nginx
else
    log "Nginx already installed, skipping"
fi

if ! rpm -q git >/dev/null 2>&1; then
    log "Installing git"
    yum install -y git
else
    log "Git already installed, skipping"
fi

if ! rpm -q htop >/dev/null 2>&1; then
    log "Installing additional packages"
    yum install -y amazon-linux-extras htop
else
    log "Additional packages already installed, skipping"
fi

# Install development tools (idempotent)
log "Installing development tools"
if ! yum grouplist installed | grep -q "Development Tools"; then
    log "Installing Development Tools group"
    yum groupinstall -y "Development Tools"
else
    log "Development Tools already installed, skipping"
fi

if ! rpm -q openssl-devel >/dev/null 2>&1 || ! rpm -q ncurses-devel >/dev/null 2>&1; then
    log "Installing development dependencies"
    yum install -y openssl-devel ncurses-devel
else
    log "Development dependencies already installed, skipping"
fi

# Install ASDF version manager (idempotent)
log "Setting up ASDF version manager"
if [ ! -d ~/.asdf ]; then
    log "Installing ASDF version manager"
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    
    # Add to bashrc only if not already present
    if ! grep -q '.asdf/asdf.sh' ~/.bashrc; then
        echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
        echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
    fi
else
    log "ASDF already installed, skipping"
fi

export PATH="$HOME/.asdf/bin:$PATH"
source ~/.asdf/asdf.sh

# Install Erlang and Elixir plugins (idempotent)
log "Setting up Erlang and Elixir plugins"
if ! asdf plugin list | grep -q erlang; then
    log "Adding Erlang plugin"
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
else
    log "Erlang plugin already installed, skipping"
fi

if ! asdf plugin list | grep -q elixir; then
    log "Adding Elixir plugin"
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
else
    log "Elixir plugin already installed, skipping"
fi

# Install specific versions (idempotent)
log "Installing Erlang and Elixir versions"
if ! asdf list erlang | grep -q "25.0.4"; then
    log "Installing Erlang 25.0.4"
    asdf install erlang 25.0.4
    asdf global erlang 25.0.4
else
    log "Erlang 25.0.4 already installed, setting as global"
    asdf global erlang 25.0.4
fi

if ! asdf list elixir | grep -q "1.18.4"; then
    log "Installing Elixir 1.18.4"
    asdf install elixir 1.18.4
    asdf global elixir 1.18.4
else
    log "Elixir 1.18.4 already installed, setting as global"
    asdf global elixir 1.18.4
fi

# Make sure asdf is available for all users (idempotent)
log "Creating global symlinks for ASDF binaries"
if [ ! -L /usr/local/bin/erl ]; then
    sudo ln -sf ~/.asdf/shims/erl /usr/local/bin/erl
fi
if [ ! -L /usr/local/bin/elixir ]; then
    sudo ln -sf ~/.asdf/shims/elixir /usr/local/bin/elixir
fi
if [ ! -L /usr/local/bin/mix ]; then
    sudo ln -sf ~/.asdf/shims/mix /usr/local/bin/mix
fi

# Configure Nginx (idempotent)
log "Configuring Nginx"

# Check if custom nginx.conf already exists with our configuration
if ! grep -q "worker_rlimit_nofile 65536" /etc/nginx/nginx.conf 2>/dev/null; then
    log "Creating custom nginx.conf"
    cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
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
    systemctl reload nginx
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

chown -R ec2-user:ec2-user /var/www/html/dbservice-$ENVIRONMENT

# Only rebuild if we cloned or updated the repository
if [ "$NEED_CLONE" = true ] || [ "$NEED_UPDATE" = true ]; then
    log "Building application (dependencies changed)"
    export MIX_ENV=prod
    
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix local.hex --force"
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix local.rebar --force"
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix deps.get"
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix deps.compile"
    
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix assets.deploy"
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix phx.digest"
    
    # Always run migrations (they're idempotent in Ecto)
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix ecto.migrate"
    
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix phx.swagger.generate"
    
    RESTART_SERVICE=true
else
    log "Application code unchanged, skipping build"
    # Still run migrations in case there are new ones
    export MIX_ENV=prod
    runuser -l ec2-user -c "cd /var/www/html/dbservice-$ENVIRONMENT && mix ecto.migrate"
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
User=ec2-user
Group=ec2-user
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

if ! rpm -q amazon-cloudwatch-agent >/dev/null 2>&1; then
    log "Installing CloudWatch agent"
    yum install -y amazon-cloudwatch-agent
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
