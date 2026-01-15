#!/bin/bash

# ASG Instance Status Checker
# This script checks the status of instances in the Auto Scaling Group

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENVIRONMENT="staging"
DEFAULT_PROJECT_NAME="dbservice-test"
DEFAULT_REGION="ap-south-1"

# Parse command line arguments
ENVIRONMENT=${1:-$DEFAULT_ENVIRONMENT}
PROJECT_NAME=${2:-$DEFAULT_PROJECT_NAME}
AWS_REGION=${3:-$DEFAULT_REGION}

ASG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-asg"

echo -e "${BLUE}=== Auto Scaling Group Status Check ===${NC}"
echo -e "${BLUE}ASG Name: ${ASG_NAME}${NC}"
echo -e "${BLUE}Region: ${AWS_REGION}${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed or not in PATH${NC}"
    exit 1
fi

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured or invalid${NC}"
        echo "Please run 'aws configure' or set up your AWS credentials"
        exit 1
    fi
}

# Function to get ASG details
get_asg_details() {
    echo -e "${YELLOW}--- Auto Scaling Group Details ---${NC}"
    
    local asg_info
    asg_info=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0]' 2>/dev/null)
    
    if [ "$asg_info" = "null" ] || [ -z "$asg_info" ]; then
        echo -e "${RED}Error: Auto Scaling Group '$ASG_NAME' not found${NC}"
        exit 1
    fi
    
    local desired_capacity min_size max_size health_check_type
    desired_capacity=$(echo "$asg_info" | jq -r '.DesiredCapacity')
    min_size=$(echo "$asg_info" | jq -r '.MinSize')
    max_size=$(echo "$asg_info" | jq -r '.MaxSize')
    health_check_type=$(echo "$asg_info" | jq -r '.HealthCheckType')
    
    echo "Desired Capacity: $desired_capacity"
    echo "Min Size: $min_size"
    echo "Max Size: $max_size"
    echo "Health Check Type: $health_check_type"
    echo ""
}

# Function to get instance details
get_instance_details() {
    echo -e "${YELLOW}--- Instance Details ---${NC}"
    
    local instances
    instances=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances[].[InstanceId,LifecycleState,HealthStatus,AvailabilityZone]' \
        --output text 2>/dev/null)
    
    if [ -z "$instances" ]; then
        echo -e "${YELLOW}No instances found in the ASG${NC}"
        return
    fi
    
    echo -e "${BLUE}Instance ID\t\tLifecycle State\t\tHealth Status\tAZ${NC}"
    echo "--------------------------------------------------------------------"
    
    while IFS=$'\t' read -r instance_id lifecycle_state health_status az; do
        # Color code based on status
        local color=$GREEN
        if [ "$lifecycle_state" != "InService" ] || [ "$health_status" != "Healthy" ]; then
            color=$RED
        fi
        
        echo -e "${color}$instance_id\t$lifecycle_state\t\t$health_status\t\t$az${NC}"
    done <<< "$instances"
    
    echo ""
}

# Function to get detailed EC2 instance status
get_ec2_instance_status() {
    echo -e "${YELLOW}--- EC2 Instance Status ---${NC}"
    
    local instance_ids
    instance_ids=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances[].InstanceId' \
        --output text 2>/dev/null)
    
    if [ -z "$instance_ids" ]; then
        echo -e "${YELLOW}No instances found${NC}"
        return
    fi
    
    local ec2_details
    ec2_details=$(aws ec2 describe-instances \
        --instance-ids $instance_ids \
        --region "$AWS_REGION" \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,LaunchTime,PublicIpAddress,PrivateIpAddress]' \
        --output text 2>/dev/null)
    
    echo -e "${BLUE}Instance ID\t\tState\t\tType\t\tLaunch Time\t\t\tPublic IP\tPrivate IP${NC}"
    echo "------------------------------------------------------------------------------------------------"
    
    while IFS=$'\t' read -r instance_id state instance_type launch_time public_ip private_ip; do
        local color=$GREEN
        if [ "$state" != "running" ]; then
            color=$RED
        fi
        
        # Format launch time (remove timezone for brevity)
        local formatted_time
        formatted_time=$(echo "$launch_time" | cut -d'T' -f1,2 | tr 'T' ' ')
        
        echo -e "${color}$instance_id\t$state\t\t$instance_type\t$formatted_time\t$public_ip\t$private_ip${NC}"
    done <<< "$ec2_details"
    
    echo ""
}

# Function to get load balancer target group health
get_target_group_health() {
    echo -e "${YELLOW}--- Load Balancer Target Group Health ---${NC}"
    
    # Get target group ARN from ASG
    local target_group_arns
    target_group_arns=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].TargetGroupARNs[]' \
        --output text 2>/dev/null)
    
    if [ -z "$target_group_arns" ]; then
        echo -e "${YELLOW}No target groups associated with this ASG${NC}"
        return
    fi
    
    for tg_arn in $target_group_arns; do
        echo "Target Group: $tg_arn"
        
        local health_status
        health_status=$(aws elbv2 describe-target-health \
            --target-group-arn "$tg_arn" \
            --region "$AWS_REGION" \
            --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
            --output text 2>/dev/null)
        
        if [ -z "$health_status" ]; then
            echo -e "${YELLOW}No targets registered${NC}"
        else
            echo -e "${BLUE}Instance ID\t\tHealth State\tDescription${NC}"
            echo "----------------------------------------------------"
            
            while IFS=$'\t' read -r instance_id health_state description; do
                local color=$GREEN
                if [ "$health_state" != "healthy" ]; then
                    color=$RED
                fi
                
                echo -e "${color}$instance_id\t$health_state\t\t$description${NC}"
            done <<< "$health_status"
        fi
        echo ""
    done
}

# Function to get ASG activities (recent scaling events)
get_asg_activities() {
    echo -e "${YELLOW}--- Recent ASG Activities (Last 10) ---${NC}"
    
    local activities
    activities=$(aws autoscaling describe-scaling-activities \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$AWS_REGION" \
        --max-items 10 \
        --query 'Activities[].[StartTime,StatusCode,Description]' \
        --output text 2>/dev/null)
    
    if [ -z "$activities" ]; then
        echo -e "${YELLOW}No recent activities found${NC}"
        return
    fi
    
    echo -e "${BLUE}Start Time\t\t\tStatus\t\tDescription${NC}"
    echo "-------------------------------------------------------------------------"
    
    while IFS=$'\t' read -r start_time status description; do
        local color=$GREEN
        if [[ "$status" =~ Failed|Cancelled ]]; then
            color=$RED
        elif [[ "$status" =~ InProgress ]]; then
            color=$YELLOW
        fi
        
        # Format time
        local formatted_time
        formatted_time=$(echo "$start_time" | cut -d'T' -f1,2 | tr 'T' ' ')
        
        echo -e "${color}$formatted_time\t$status\t\t$description${NC}"
    done <<< "$activities"
    
    echo ""
}

# Function to display usage
usage() {
    echo "Usage: $0 [environment] [project_name] [aws_region]"
    echo ""
    echo "Arguments:"
    echo "  environment   Environment name (default: $DEFAULT_ENVIRONMENT)"
    echo "  project_name  Project name (default: $DEFAULT_PROJECT_NAME)"
    echo "  aws_region    AWS region (default: $DEFAULT_REGION)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use default values"
    echo "  $0 production                         # Check production environment"
    echo "  $0 staging dbservice-test ap-south-1  # Full specification"
    echo ""
}

# Main execution
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi
    
    echo -e "${GREEN}Checking AWS credentials...${NC}"
    check_aws_credentials
    
    echo -e "${GREEN}Fetching ASG information...${NC}"
    get_asg_details
    
    echo -e "${GREEN}Fetching instance details...${NC}"
    get_instance_details
    
    echo -e "${GREEN}Fetching EC2 status...${NC}"
    get_ec2_instance_status
    
    echo -e "${GREEN}Fetching load balancer health...${NC}"
    get_target_group_health
    
    echo -e "${GREEN}Fetching recent activities...${NC}"
    get_asg_activities
    
    echo -e "${GREEN}=== Status check complete ===${NC}"
}

# Run main function
main "$@"
