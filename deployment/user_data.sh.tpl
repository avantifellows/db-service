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
    
    # Install Elixir using the new method in ubuntu user's home
    echo "Installing Elixir 1.18.4 with OTP 27.3.4..."
    export HOME=/home/ubuntu
    curl -fsSO https://elixir-lang.org/install.sh
    sudo -u ubuntu HOME=/home/ubuntu sh install.sh elixir@1.18.4 otp@27.3.4
    installs_dir=/home/ubuntu/.elixir-install/installs
    export PATH=$installs_dir/otp/27.3.4/bin:$PATH
    export PATH=$installs_dir/elixir/1.18.4-otp-27/bin:$PATH

    # Set capability for BEAM to bind to privileged ports
    echo "Setting capability for BEAM to bind to privileged ports..."
    setcap 'cap_net_bind_service=+ep' /home/ubuntu/.elixir-install/installs/otp/27.3.4/erts-15.2.7/bin/beam.smp
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
PATH_TO_CREDENTIALS=${PATH_TO_CREDENTIALS}
EOF

    # Copy .env to config
    cp .env config/.env

    # Ensure AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI not found. Installing..."
        apt update -y
        apt install awscli -y
    fi
    # Retrieve ETL flow key file from AWS Secrets Manager if it doesn't exist
    if [ ! -f "/home/ubuntu/db-service/config/etl-flow-key.json" ]; then
        echo "ETL flow key file not found. Retrieving from AWS Secrets Manager..."
        if aws secretsmanager get-secret-value \
            --secret-id "etl-flow-key" \
            --query 'SecretString' \
            --output text \
            --region ap-south-1 > /home/ubuntu/db-service/config/etl-flow-key.json 2>/dev/null; then
            
            echo "Successfully retrieved ETL flow key file"
            # Set proper permissions for the key file
            chmod 600 /home/ubuntu/db-service/config/etl-flow-key.json
            chown ubuntu:ubuntu /home/ubuntu/db-service/config/etl-flow-key.json
        else
            echo "Warning: Failed to retrieve ETL flow key file from Secrets Manager"
            echo "Please ensure the secret 'etl-flow-key' exists and EC2 has proper IAM permissions"
        fi
    else
        echo "ETL flow key file already exists, skipping retrieval from Secrets Manager"
    fi
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
    
    # Set Elixir PATH
    installs_dir=/home/ubuntu/.elixir-install/installs
    export PATH=$installs_dir/otp/27.3.4/bin:$PATH
    export PATH=$installs_dir/elixir/1.18.4-otp-27/bin:$PATH
    
    echo "Setting up Elixir environment..."
    MIX_ENV=prod mix local.hex --force
    MIX_ENV=prod mix local.rebar --force
    
    echo "Installing and compiling dependencies..."
    MIX_ENV=prod mix deps.get
    MIX_ENV=prod mix deps.compile
    MIX_ENV=prod mix tailwind.install
    
    echo "Running migrations..."
    MIX_ENV=prod mix ecto.migrate
    
    echo "Generating swagger..."
    MIX_ENV=prod mix phx.swagger.generate

    echo "Deploying assets"
    MIX_ENV=prod mix assets.deploy
    
    echo "Starting Phoenix server..."
    prlimit --nofile=1048576 -- MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
}

# Set ulimit values
echo "Setting ulimit values..."
if ! grep -q "nofile 1048576" /etc/security/limits.conf; then
    echo "root soft nofile 1048576" >> /etc/security/limits.conf
    echo "root hard nofile 1048576" >> /etc/security/limits.conf
fi

# Add Elixir and Erlang to PATH for all future sessions
echo 'export PATH=/home/ubuntu/.elixir-install/installs/otp/27.3.4/bin:$PATH' >> /home/ubuntu/.profile
echo 'export PATH=/home/ubuntu/.elixir-install/installs/elixir/1.18.4-otp-27/bin:$PATH' >> /home/ubuntu/.profile

# Main execution
install_system_dependencies
setup_cloudwatch
setup_application
stop_existing_application
start_application

echo "[$(date)] Completed user_data script execution"

--//