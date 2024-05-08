#!/bin/bash

# Specify the log file
LOG_FILE="/var/log/user_data.log"

# Sleep for 60 seconds
echo "Sleeping for 60 seconds before executing commands..."
sleep 60

# Use exec to redirect all stdout and stderr to the log file from this point on
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "Starting user_data script execution"

# No need for 'sudo su' when running as user data, the script runs with root privileges by default

# Update the system
echo "Running system update..."
sudo apt update -y

# Update the system
echo "Running system upgrade..."
sudo apt upgrade -y

# Install elixir
echo "Installing Elixir..."
sudo apt install elixir -y

# Install rebar
sudo apt-get install rebar -y

# Install erlang-dev
sudo apt install erlang-dev -y

# Install xmerl
sudo apt-get install erlang-xmerl -y

# Clone the repository
echo "Cloning the repository..."
git clone https://github.com/avantifellows/db-service.git /home/ubuntu/db-service

# echo "Changing access permissions for the directory..."
# sudo chown -R ubuntu:ubuntu /var/ubuntu/db-service

echo "Checking out a branch..."
cd /home/ubuntu/db-service
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
echo "DATABASE_URL=${DATABASE_URL}" >> .env
echo "PHX_HOST=$HOST_IP" >> .env
echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> .env
echo "WHITELISTED_DOMAINS=$HOST_IP" >> .env
echo "BEARER_TOKEN=${BEARER_TOKEN}" >> .env
echo "PORT=${PORT}" >> .env
echo "POOL_SIZE=${POOL_SIZE}" >> .env

# copy .env to config/env
sudo cp .env config/.env

# Sleep for 30 seconds
# echo "Sleeping for 30 seconds before executing commands..."
# sleep 30

# Install hex
echo "Installing hex..."
sudo MIX_ENV=prod mix local.hex --force

# Install rebar
echo "Installing rebar..."
sudo MIX_ENV=prod mix local.rebar --force

# Installing dependencies
echo "Installing dependencies..."
sudo MIX_ENV=prod mix deps.get

# Compiling dependencies
echo "Compiling dependencies..."
sudo MIX_ENV=prod mix deps.compile

echo "Generating swagger..."
sudo MIX_ENV=prod mix phx.swagger.generate

# Start Phoenix server
cd /home/ubuntu/db-service
echo "Starting Db service server..."
sudo MIX_ENV=prod elixir --erl "-detached" -S mix phx.server

# Install Amazon CloudWatch Agent
# echo "Installing amazon-cloudwatch-agent..."
# sudo apt install amazon-cloudwatch-agent -y
