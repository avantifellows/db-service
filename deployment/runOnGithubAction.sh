#!/bin/bash 

# Define variables
echo "Defining variables..."
ENV_NAME_PREFIX="${ENVIRONMENT_PREFIX}" # Remove trailing dash if present
ASG_PATTERN="${ENV_NAME_PREFIX}asg"
echo "Looking for ASG with pattern: $ASG_PATTERN"

# Read environment variables from GitHub Secrets
echo "Reading environment variables from GitHub Secrets..."
BRANCH_NAME_TO_DEPLOY="${BRANCH_NAME_TO_DEPLOY}"
TARGET_GROUP_NAME="${TARGET_GROUP_NAME}"
DATABASE_URL="${DATABASE_URL}"
SECRET_KEY_BASE="${SECRET_KEY_BASE}"
BEARER_TOKEN="${BEARER_TOKEN}"
PORT="${PORT}"
POOL_SIZE="${POOL_SIZE}"

# Find the correct ASG name with pattern matching
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, '${ASG_PATTERN}')].AutoScalingGroupName" \
  --output text)

if [ -z "$ASG_NAME" ]; then
    echo "Error: Could not find Auto Scaling Group with pattern $ASG_PATTERN"
    exit 1
fi

echo "Using Auto Scaling Group: $ASG_NAME"

# Get Launch Template ID from ASG
echo "Getting Launch Template ID..."
LAUNCH_TEMPLATE_ID=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId' \
    --output text)

if [ -z "$LAUNCH_TEMPLATE_ID" ]; then
    echo "Error: Could not find Launch Template ID"
    exit 1
fi

echo "Using Launch Template ID: $LAUNCH_TEMPLATE_ID"

# Create the cloud-config header for user data
echo "Creating cloud-config user data..."
CLOUD_CONFIG_HEADER='Content-Type: multipart/mixed; boundary="//"
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

'

# Process user data template with current environment variables
echo "Processing user data template..."
PROCESSED_USER_DATA=$(cat deployment/user_data.sh.tpl | \
    sed "s|\${BRANCH_NAME_TO_DEPLOY}|$BRANCH_NAME_TO_DEPLOY|g" | \
    sed "s|\${TARGET_GROUP_NAME}|$TARGET_GROUP_NAME|g" | \
    sed "s|\${environment_prefix}|$ENVIRONMENT_PREFIX|g" | \
    sed "s|\${DATABASE_URL}|$DATABASE_URL|g" | \
    sed "s|\${SECRET_KEY_BASE}|$SECRET_KEY_BASE|g" | \
    sed "s|\${BEARER_TOKEN}|$BEARER_TOKEN|g" | \
    sed "s|\${PORT}|$PORT|g" | \
    sed "s|\${POOL_SIZE}|$POOL_SIZE|g" | \
    sed "s|\${LOG_FILE}|/home/ubuntu/db-service/logs/user_data.log|g")

# Combine cloud-config header with processed user data and add the footer
FINAL_USER_DATA="${CLOUD_CONFIG_HEADER}${PROCESSED_USER_DATA}

--//"

# Check for any remaining template variables
echo "Checking processed user data for any remaining template variables..."
if grep -q "\${" <<< "$FINAL_USER_DATA"; then
  echo "WARNING: Found unparsed variables in user data:"
  grep "\${" <<< "$FINAL_USER_DATA"
fi

# Create new launch template version with updated user data
echo "Creating new Launch Template version..."
NEW_VERSION=$(aws ec2 create-launch-template-version \
    --launch-template-id "$LAUNCH_TEMPLATE_ID" \
    --source-version '$Latest' \
    --launch-template-data "{\"UserData\":\"$(echo "$FINAL_USER_DATA" | base64 -w 0)\"}" \
    --query 'LaunchTemplateVersion.VersionNumber' \
    --output text)

if [ -z "$NEW_VERSION" ]; then
    echo "Error: Failed to create new Launch Template version"
    exit 1
fi

echo "Created new Launch Template version: $NEW_VERSION"

# Verify new launch template version
echo "Verifying new launch template version..."
aws ec2 describe-launch-template-versions \
  --launch-template-id "$LAUNCH_TEMPLATE_ID" \
  --versions "$NEW_VERSION" \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData.UserData' \
  --output text | base64 -d | grep -A 5 "Content-Type: multipart/mixed"

# Update ASG to use new template version
echo "Updating ASG to use new template version..."
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template LaunchTemplateId="$LAUNCH_TEMPLATE_ID",Version="$NEW_VERSION"

# Get all running instances in the ASG
echo "Getting instances in ASG..."
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "No instances found in ASG"
else
    # Reboot all instances
    echo "Rebooting instances..."
    aws ec2 reboot-instances --instance-ids $INSTANCE_IDS
    
    # Wait for instances to come back online
    echo "Waiting for instances to reboot..."
    for INSTANCE_ID in $INSTANCE_IDS; do
        echo "Waiting for instance $INSTANCE_ID to become running..."
        aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
        echo "Instance $INSTANCE_ID is now running"
    done
fi

# After waiting for instances to be running
for INSTANCE_ID in $INSTANCE_IDS; do
    INSTANCE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
    echo "Checking deployment status on $INSTANCE_IP..."
    
    # Loop until deployment is complete or timeout
    timeout=600 # 10 minutes
    start_time=$(date +%s)
    while true; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            echo "Timeout waiting for deployment to complete on $INSTANCE_IP"
            break
        fi
        
        # Check if deployment is complete by looking for a success marker in logs
        if ssh -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "grep 'Deployment completed successfully' /home/ubuntu/db-service/logs/user_data.log"; then
            echo "Deployment completed on $INSTANCE_IP"
            break
        fi
        
        echo "Deployment still in progress on $INSTANCE_IP, waiting..."
        sleep 30
    done
done

echo "Deployment completed successfully"