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

# Setup logging
LOG_FILE="${LOG_FILE}"
exec > >(tee -a $LOG_FILE) 2>&1

echo "Sleeping for 60 seconds before executing commands..."
sleep 60

echo "[$(date)] Starting user_data script execution"

# Function to install system dependencies
install_system_dependencies() {
    echo "Checking and installing system dependencies..."
    apt update -y
    apt upgrade -y
    
    # Install required packages if not present
    for package in elixir rebar erlang-dev erlang-xmerl; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            echo "Installing $package..."
            apt install -y $package
        else
            echo "$package is already installed"
        fi
    done
}

# Function to setup CloudWatch agent
setup_cloudwatch() {
    if [ ! -f "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl" ]; then
        echo "Installing CloudWatch agent..."
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        dpkg -i -E ./amazon-cloudwatch-agent.deb
    else
        echo "CloudWatch agent is already installed"
    fi

    # Configure and start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${environment_prefix}cloudwatch-agent-config
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
}

# Function to setup application
setup_application() {
    export HOME=/home/ubuntu
    
    # Create and set permissions for application directory
    if [ ! -d "/home/ubuntu/db-service" ]; then
        echo "Cloning repository..."
        git clone https://github.com/avantifellows/db-service.git /home/ubuntu/db-service
    fi

    echo "Setting up application repository..."
    chown -R ubuntu:ubuntu /home/ubuntu/db-service
    cd /home/ubuntu/db-service

    git config --global --add safe.directory /home/ubuntu/db-service

    # Ensure we are on the correct branch
    git fetch --all
    git stash
    git checkout ${BRANCH_NAME_TO_DEPLOY}
    git pull origin ${BRANCH_NAME_TO_DEPLOY}

    # Create logs directory if needed
    mkdir -p /home/ubuntu/db-service/logs

    # Setup environment file
    HOST_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    cat > .env << EOF
BRANCH_NAME_TO_DEPLOY=${BRANCH_NAME_TO_DEPLOY}
TARGET_GROUP_NAME=${TARGET_GROUP_NAME}
ENVIRONMENT_PREFIX=${environment_prefix}
HOST_IP=$HOST_IP
DATABASE_URL=${DATABASE_URL}
PHX_HOST=$HOST_IP
SECRET_KEY_BASE=${SECRET_KEY_BASE}
BEARER_TOKEN=${BEARER_TOKEN}
PORT=${PORT}
POOL_SIZE=${POOL_SIZE}
EOF

    # Copy .env to config
    cp .env config/.env
}

# Function to stop the running application if it's already running
stop_existing_application() {
    echo "Checking for existing application process running on port ${PORT}..."
    PID=$(sudo lsof -t -i :${PORT})

    if [ -n "$PID" ]; then
        echo "Process found with PID $PID. Restarting the application..."
        kill $PID
        echo "Process terminated."
    else
        echo "No existing process found on port ${PORT}."
    fi
}

# Function to start application
start_application() {
    cd /home/ubuntu/db-service

    # Ensure HOME is set
    export HOME=/home/ubuntu
    
    echo "Setting up Elixir environment..."
    MIX_ENV=prod mix local.hex --force
    MIX_ENV=prod mix local.rebar --force
    
    echo "Installing and compiling dependencies..."
    MIX_ENV=prod mix deps.get
    MIX_ENV=prod mix deps.compile
    
    echo "Running migrations..."
    MIX_ENV=prod mix ecto.migrate
    
    echo "Generating swagger..."
    MIX_ENV=prod mix phx.swagger.generate
    
    echo "Starting Phoenix server..."
    MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
}

# Set ulimit values
echo "Setting ulimit values..."
if ! grep -q "nofile 1048576" /etc/security/limits.conf; then
    echo "root soft nofile 1048576" >> /etc/security/limits.conf
    echo "root hard nofile 1048576" >> /etc/security/limits.conf
fi

# Main execution
install_system_dependencies
setup_cloudwatch
setup_application
stop_existing_application
start_application

echo "[$(date)] Completed user_data script execution"

--//