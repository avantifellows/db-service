#!/bin/bash

# Define variables
echo "Defining variables..."
ENV_NAME_PREFIX="${ENVIRONMENT_PREFIX}" # Remove trailing dash if present
ASG_PATTERN="${ENV_NAME_PREFIX}asg"
echo "Looking for ASG with pattern: $ASG_PATTERN"

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

# Ensure no leftover template variables
echo "Checking processed user data for any remaining template variables..."
if grep -q "\${" <<< "$PROCESSED_USER_DATA"; then
  echo "WARNING: Found unparsed variables in user data:"
  grep "\${" <<< "$PROCESSED_USER_DATA"
fi

# Update user data in Launch Template
echo "Creating new Launch Template version..."
NEW_VERSION=$(aws ec2 create-launch-template-version \
    --launch-template-id "$LAUNCH_TEMPLATE_ID" \
    --source-version '$Latest' \
    --launch-template-data "{\"UserData\":\"$(echo \"$PROCESSED_USER_DATA\" | base64 -w 0)\"}" \
    --query 'LaunchTemplateVersion.VersionNumber' \
    --output text)

if [ -z "$NEW_VERSION" ]; then
    echo "Error: Failed to create new Launch Template version"
    exit 1
fi

echo "Created new Launch Template version: $NEW_VERSION"

# Get current ASG capacity before scaling down
echo "Getting current ASG capacity..."
CURRENT_DESIRED=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text)

echo "Current desired capacity: $CURRENT_DESIRED"

# Update ASG to use new template version
echo "Updating ASG to use new template version..."
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template LaunchTemplateId="$LAUNCH_TEMPLATE_ID",Version="$NEW_VERSION"

# Reboot instances instead of terminating them
echo "Rebooting instances to apply changes..."
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

for INSTANCE_ID in $INSTANCE_IDS; do
  echo "Rebooting instance $INSTANCE_ID..."
  aws ec2 reboot-instances --instance-ids "$INSTANCE_ID"
done

# Wait for instances to come back online
echo "Waiting for instances to initialize..."
sleep 60  # Adjust based on expected instance reboot time

echo "Verifying instances are using the new launch template version..."
for INSTANCE_ID in $INSTANCE_IDS; do
  echo "Checking instance $INSTANCE_ID..."
  aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].LaunchTemplate.Version' \
    --output text
done

echo "Deployment completed successfully"