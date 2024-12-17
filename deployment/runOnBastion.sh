#!/bin/bash

# Set AWS Region explicitly
export AWS_DEFAULT_REGION="ap-south-1"
export AWS_REGION="ap-south-1"

# Ensure AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "[SETUP] AWS CLI not found. Installing AWS CLI..."
    sudo apt-get update
    sudo apt-get install -y awscli
fi

# extract TARGET_GROUP_NAME from .env file and store it in an environment variable
TARGET_GROUP_NAME=$(grep TARGET_GROUP_NAME .env | cut -d '=' -f2)

# Define variables
echo "[EC2 Action] Defining variables..."
targetGroupName=$TARGET_GROUP_NAME
region="ap-south-1" # replace with your actual region
account_id="111766607077" # replace with your actual account ID

# Fetch the ARN of the target group by its name
echo "[EC2 Action] Fetching ARN for target group named $targetGroupName..."
targetGroupArn=$(aws elbv2 describe-target-groups --names $targetGroupName --query "TargetGroups[0].TargetGroupArn" --output text --region $region)

# Check if we successfully retrieved the ARN
if [ -z "$targetGroupArn" ]; then
    echo "[EC2 Action] Error: Could not retrieve ARN for target group named $targetGroupName."
    exit 1
fi

echo "[EC2 Action] Found ARN for target group: $targetGroupArn"

keyPath="/home/ubuntu/AvantiFellows.pem"
envFile="/home/ubuntu/.env"
pathToCloudwatchConfig="/home/ubuntu/db-service/deployment/cloudwatch-agent-config.json"

# Fetch the instance IDs of the target group using the ARN
echo "[EC2 Action] Fetching instance IDs of the target group..."
instanceIds=$(aws elbv2 describe-target-health --target-group-arn $targetGroupArn --query "TargetHealthDescriptions[*].Target.Id" --output text --region $region)

echo "[EC2 Action] Fetching private IP addresses of the instances..."
privateIps=$(aws ec2 describe-instances --instance-ids $instanceIds --query "Reservations[*].Instances[*].PrivateIpAddress" --output text --region $region)

# Convert the space-separated strings into arrays
instanceIdsArray=($instanceIds)
privateIpsArray=($privateIps)

# extract BRANCH_NAME_TO_DEPLOY from .env file and store it in an environment variable
BRANCH_NAME_TO_DEPLOY=$(grep BRANCH_NAME_TO_DEPLOY $envFile | cut -d '=' -f2)

for i in "${!instanceIdsArray[@]}"; do
    id=${instanceIdsArray[$i]}
    private_ip=${privateIpsArray[$i]}
    echo "[EC2 Action] Processing instance ID: $id"

    # Get private IP of the instance
    echo "[EC2 Action] Getting private IP of instance $id..."
    instanceIp=$(aws ec2 describe-instances --instance-ids $id --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)

    echo "[EC2 Action] Changing access permissions for the directory..."
    ssh -o StrictHostKeyChecking=no -i $keyPath ubuntu@$instanceIp "sudo chown -R ubuntu:ubuntu /home/ubuntu/db-service"

    # Transfer .env file
    echo "[EC2 Action] Transferring .env file to instance $id at IP $instanceIp..."
    scp -o StrictHostKeyChecking=no -i $keyPath $envFile ubuntu@$instanceIp:/home/ubuntu/db-service

# Execute commands on the instance using a bash script
    echo "[EC2 Action] Executing deployment script on instance $id..."
    ssh -o StrictHostKeyChecking=no -i $keyPath ubuntu@$instanceIp << 'EOSSH'
#!/bin/bash
set -e  # Exit on any error
set -x  # Print commands for debugging

# Ensure we have a log file for debugging
LOG_FILE="/tmp/deployment_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting deployment process..."

# Kill any existing process on port 80
sudo fuser -k 80/tcp || true

# Change to project directory
cd /home/ubuntu/db-service

# Stash any local changes
git stash

# Checkout and pull the specified branch
git checkout $BRANCH_NAME_TO_DEPLOY
git pull origin $BRANCH_NAME_TO_DEPLOY

# Add instance-specific environment variables
echo "HOST_IP=$(hostname -I | awk '{print $1}')" >> .env
echo "PHX_HOST=$(hostname -I | awk '{print $1}')" >> .env

# Ensure mix is available
sudo MIX_ENV=prod mix local.hex --force
sudo MIX_ENV=prod mix local.rebar --force

# Install and compile dependencies with verbose output
echo "Installing dependencies..."
sudo MIX_ENV=prod mix deps.get || { echo "Failed to get dependencies"; exit 1; }

echo "Compiling dependencies..."
sudo MIX_ENV=prod mix deps.compile || { echo "Failed to compile dependencies"; exit 1; }

# Run migrations with verbose output
echo "Running database migrations..."
sudo MIX_ENV=prod mix ecto.migrate || { echo "Migration failed"; exit 1; }

# Generate Swagger documentation
echo "Generating Swagger documentation..."
sudo MIX_ENV=prod mix phx.swagger.generate || { echo "Swagger generation failed"; exit 1; }

# Stop any existing server
echo "Stopping any existing server processes..."
pkill -f "mix phx.server" || true

# Start the server in detached mode
echo "Starting Phoenix server..."
sudo MIX_ENV=prod elixir --erl "-detached" -S mix phx.server || { 
    echo "Failed to start server"
    cat "$LOG_FILE"
    exit 1
}

# Verify the server is running
sleep 10
if ! pgrep -f "mix phx.server" > /dev/null; then
    echo "Server failed to start. Check logs:"
    cat "$LOG_FILE"
    exit 1
fi

echo "Deployment completed successfully!"
echo "Log file saved to: $LOG_FILE"
EOSSH

    echo "[EC2 Action] Completed actions on instance $id."
done

echo "[EC2 Action] Completed updating all instances in target group."