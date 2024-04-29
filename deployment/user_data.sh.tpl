#!/bin/bash

# Specify the log file
LOG_FILE="/var/log/user_data.log"

# Use exec to redirect all stdout and stderr to the log file from this point on
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "Starting user_data script execution"

# No need for 'sudo su' when running as user data, the script runs with root privileges by default

# Update the system
echo "Running system update..."
yum update -y

# Install Git
echo "Installing Git..."
dnf install git -y

# Install elixir
echo "Installing Elixir..."
yum install elixir

# Clone the repository
echo "Cloning the repository..."
git clone https://github.com/avantifellows/db-service.git /home/ec2-user/db-service

# echo "Changing access permissions for the directory..."
# sudo chown -R ec2-user:ec2-user /home/ec2-user/db-service

echo "Checking out a branch..."
cd /home/ec2-user/db-service
git stash
git checkout ${BRANCH_NAME_TO_DEPLOY}
git pull origin ${BRANCH_NAME_TO_DEPLOY}

echo "Setting env file..."
touch .env
echo "BRANCH_NAME_TO_DEPLOY=${BRANCH_NAME_TO_DEPLOY}" >> .env
echo "TARGET_GROUP_NAME=${TARGET_GROUP_NAME}" >> .env
echo "ENVIRONMENT_PREFIX=${environment_prefix}" >> .env
HOST_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
echo "HOST_IP=$HOST_IP" >> .env

# Install requirements
echo "Installing requirements..."
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix deps.compile

echo "Running migrations..."
MIX_ENV=prod mix ecto.migrate

echo "Generating swagger..."
MIX_ENV=prod mix phx.swagger.generate

# Start Phoenix server
cd /home/ec2-user/db-service
echo "Starting Db service server..."
MIX_ENV=prod elixir --erl "-detached" -S mix phx.server
 > /home/ec2-user/db-service/logs/info.log 2>&1 &
#> /home/ec2-user/db-service/logs/info.log 2>&1 &


# Install Amazon CloudWatch Agent
# echo "Installing amazon-cloudwatch-agent..."
# sudo yum install amazon-cloudwatch-agent -y
