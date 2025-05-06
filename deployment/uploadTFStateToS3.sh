#!/bin/bash

# Configuration variables - update these with your specific values
S3_BUCKET_NAME="dbservice-tf-state-backup"
BACKUP_PREFIX="dbservice-tf-backups"  # S3 prefix/folder for backups
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
AWS_REGION="ap-south-1"  # Specify your preferred AWS region

# Directory containing Terraform files (defaults to current directory)
TF_DIR="."
# Specifically, we're looking at the deployment directory
DEPLOYMENT_DIR="${TF_DIR}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if the deployment directory exists
if [ ! -d "$DEPLOYMENT_DIR" ]; then
    echo "Error: Deployment directory '$DEPLOYMENT_DIR' does not exist."
    echo "Please run this script from the root of your db-service project."
    exit 1
fi

# Check if S3 bucket exists and create it if it doesn't
echo "Checking if S3 bucket exists..."
if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
    echo "Bucket does not exist. Creating bucket: $S3_BUCKET_NAME"
    aws s3api create-bucket \
        --bucket "$S3_BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create S3 bucket."
        exit 1
    fi
    
    # Enable versioning on the bucket for additional protection
    echo "Enabling versioning on the bucket..."
    aws s3api put-bucket-versioning \
        --bucket "$S3_BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Add lifecycle policy to expire old backups after 90 days
    echo "Adding lifecycle policy to expire old backups after 90 days..."
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$S3_BUCKET_NAME" \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "Delete old backups",
                    "Status": "Enabled",
                    "Prefix": "'$BACKUP_PREFIX'/",
                    "Expiration": {
                        "Days": 90
                    }
                }
            ]
        }'
else
    echo "Bucket exists, proceeding with backup..."
fi

# Create a temporary directory for organizing files
TEMP_DIR="/tmp/dbservice-tf-backup-$TIMESTAMP"
mkdir -p "$TEMP_DIR"

echo "Creating Terraform backup..."

# Copy essential Terraform directories and files
echo "Copying Terraform configuration files..."
cp -r "$DEPLOYMENT_DIR/environments" "$TEMP_DIR/" 2>/dev/null || true
cp -r "$DEPLOYMENT_DIR/terraform.tfstate.d" "$TEMP_DIR/" 2>/dev/null || true
cp "$DEPLOYMENT_DIR/.terraform.lock.hcl" "$TEMP_DIR/" 2>/dev/null || true

# Selectively copy .terraform directory (excluding large provider files)
echo "Copying .terraform directory (excluding providers)..."
mkdir -p "$TEMP_DIR/.terraform"
if [ -d "$DEPLOYMENT_DIR/.terraform/modules" ]; then
    cp -r "$DEPLOYMENT_DIR/.terraform/modules" "$TEMP_DIR/.terraform/"
fi

# Backup any tfvars files
echo "Copying variable files..."
find "$DEPLOYMENT_DIR" -name "*.tfvars" -exec cp {} "$TEMP_DIR/" \; 2>/dev/null || true

# Backup any .tf files in the root deployment directory
echo "Copying Terraform definition files..."
find "$DEPLOYMENT_DIR" -maxdepth 1 -name "*.tf" -exec cp {} "$TEMP_DIR/" \; 2>/dev/null || true

# Create a zip file of the Terraform state and config
TEMP_ZIP_FILE="/tmp/dbservice-tf-state-backup-$TIMESTAMP.zip"
echo "Creating backup archive: $TEMP_ZIP_FILE"
(cd "$TEMP_DIR" && zip -r "$TEMP_ZIP_FILE" . -x "*.git*" "*.terraform/providers*")

if [ $? -ne 0 ]; then
    echo "Error: Failed to create ZIP archive."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Upload the zip file to S3
S3_KEY="$BACKUP_PREFIX/$TIMESTAMP/dbservice-terraform-backup.zip"
echo "Uploading Terraform state backup to s3://$S3_BUCKET_NAME/$S3_KEY"
aws s3 cp "$TEMP_ZIP_FILE" "s3://$S3_BUCKET_NAME/$S3_KEY"

if [ $? -eq 0 ]; then
    echo "Backup successfully uploaded to S3"
    echo "S3 URI: s3://$S3_BUCKET_NAME/$S3_KEY"
    
    # Clean up temporary files
    rm "$TEMP_ZIP_FILE"
    rm -rf "$TEMP_DIR"
    echo "Temporary files removed"
else
    echo "Error: Failed to upload backup to S3."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# List recent backups in the S3 bucket
echo "Recent backups in S3 bucket:"
aws s3 ls "s3://$S3_BUCKET_NAME/$BACKUP_PREFIX/" --recursive | sort | tail -5

echo "Backup process completed successfully."