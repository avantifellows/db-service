#!/bin/bash

# Instance Refresh Status Checker
# This script checks the status and percentage of instance refresh operations in the Auto Scaling Group

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENVIRONMENT="staging"
DEFAULT_PROJECT_NAME="dbservice-test"
DEFAULT_REGION="ap-south-1"

# Initialize variables
CANCEL_AND_RESTART=false
WATCH_MODE=false
ENVIRONMENT=""
PROJECT_NAME=""
AWS_REGION=""

# Function to display usage
usage() {
    echo "Usage: $0 [options] [environment] [project_name] [aws_region] [watch]"
    echo ""
    echo "Options:"
    echo "  --cancel-and-restart    Cancel current instance refresh and start a new one"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Arguments:"
    echo "  environment   Environment name (default: $DEFAULT_ENVIRONMENT)"
    echo "  project_name  Project name (default: $DEFAULT_PROJECT_NAME)"
    echo "  aws_region    AWS region (default: $DEFAULT_REGION)"
    echo "  watch         Set to 'watch' for continuous monitoring"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Check current status"
    echo "  $0 production                         # Check production environment"
    echo "  $0 staging dbservice-test ap-south-1  # Full specification"
    echo "  $0 watch                              # Continuous monitoring"
    echo "  $0 --cancel-and-restart               # Cancel current and start new refresh"
    echo "  $0 --cancel-and-restart production    # Cancel and restart for production"
    echo ""
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cancel-and-restart)
                CANCEL_AND_RESTART=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            watch)
                WATCH_MODE=true
                shift
                ;;
            *)
                # Positional arguments
                if [ -z "$ENVIRONMENT" ]; then
                    ENVIRONMENT=$1
                elif [ -z "$PROJECT_NAME" ]; then
                    PROJECT_NAME=$1
                elif [ -z "$AWS_REGION" ]; then
                    AWS_REGION=$1
                fi
                shift
                ;;
        esac
    done

    # Set defaults for unset variables
    ENVIRONMENT=${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}
    AWS_REGION=${AWS_REGION:-$DEFAULT_REGION}
}

# Initialize after parsing arguments
initialize() {
    ASG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-asg"
    
    echo -e "${BLUE}=== Instance Refresh Status Check ===${NC}"
    echo -e "${BLUE}ASG Name: ${ASG_NAME}${NC}"
    echo -e "${BLUE}Region: ${AWS_REGION}${NC}"
    echo ""
}

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

# Function to format timestamp
format_timestamp() {
    local timestamp=$1
    if [ "$timestamp" != "null" ] && [ -n "$timestamp" ]; then
        # Convert ISO timestamp to readable format
        echo "$timestamp" | sed 's/T/ /' | sed 's/+00:00//'
    else
        echo "N/A"
    fi
}

# Function to get progress bar
get_progress_bar() {
    local percentage=$1
    local width=30
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    printf "["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %3d%%" $percentage
}

# Function to get status color
get_status_color() {
    local status=$1
    case $status in
        "Successful")
            echo $GREEN
            ;;
        "InProgress")
            echo $YELLOW
            ;;
        "Failed"|"Cancelled")
            echo $RED
            ;;
        *)
            echo $NC
            ;;
    esac
}

# Function to check instance refresh status
check_refresh_status() {
    echo -e "${GREEN}Fetching instance refresh data...${NC}"
    
    local refresh_data
    refresh_data=$(aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'InstanceRefreshes[0]' 2>/dev/null)
    
    if [ "$refresh_data" = "null" ] || [ -z "$refresh_data" ]; then
        echo -e "${YELLOW}No instance refresh operations found for ASG: $ASG_NAME${NC}"
        return 1
    fi
    
    # Extract refresh details using jq
    local refresh_id status percentage start_time end_time status_reason instances_to_update
    refresh_id=$(echo "$refresh_data" | jq -r '.InstanceRefreshId // "N/A"')
    status=$(echo "$refresh_data" | jq -r '.Status // "Unknown"')
    percentage=$(echo "$refresh_data" | jq -r '.PercentageComplete // 0')
    start_time=$(echo "$refresh_data" | jq -r '.StartTime // null')
    end_time=$(echo "$refresh_data" | jq -r '.EndTime // null')
    status_reason=$(echo "$refresh_data" | jq -r '.StatusReason // "No additional information"')
    instances_to_update=$(echo "$refresh_data" | jq -r '.InstancesToUpdate // 0')
    
    # Format timestamps
    local formatted_start_time formatted_end_time
    formatted_start_time=$(format_timestamp "$start_time")
    formatted_end_time=$(format_timestamp "$end_time")
    
    # Get status color
    local status_color
    status_color=$(get_status_color "$status")
    
    # Display refresh information
    echo -e "${CYAN}=== Instance Refresh Details ===${NC}"
    echo -e "${BLUE}Refresh ID:${NC} $refresh_id"
    echo -e "${BLUE}Status:${NC} ${status_color}$status${NC}"
    echo -e "${BLUE}Progress:${NC} $(get_progress_bar $percentage)"
    echo -e "${BLUE}Instances to Update:${NC} $instances_to_update"
    echo -e "${BLUE}Start Time:${NC} $formatted_start_time"
    
    if [ "$end_time" != "null" ] && [ "$end_time" != "" ]; then
        echo -e "${BLUE}End Time:${NC} $formatted_end_time"
    fi
    
    echo -e "${BLUE}Status Reason:${NC} $status_reason"
    echo ""
    
    # Show key preferences
    local min_healthy warmup
    min_healthy=$(echo "$refresh_data" | jq -r '.Preferences.MinHealthyPercentage // "N/A"')
    warmup=$(echo "$refresh_data" | jq -r '.Preferences.InstanceWarmup // "N/A"')
    
    echo -e "${CYAN}=== Refresh Settings ===${NC}"
    echo -e "${BLUE}Min Healthy Percentage:${NC} $min_healthy%"
    echo -e "${BLUE}Instance Warmup:${NC} ${warmup}s"
    echo ""
    
    # Return status for monitoring
    echo "$status"
}

# Function to cancel current instance refresh
cancel_instance_refresh() {
    echo -e "${YELLOW}Checking for active instance refresh...${NC}"
    
    local current_status
    current_status=$(aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'InstanceRefreshes[0].Status' \
        --output text 2>/dev/null)
    
    if [ "$current_status" = "InProgress" ] || [ "$current_status" = "Pending" ]; then
        echo -e "${YELLOW}Found active instance refresh with status: $current_status${NC}"
        echo -e "${YELLOW}Cancelling current instance refresh...${NC}"
        
        local cancel_result
        cancel_result=$(aws autoscaling cancel-instance-refresh \
            --auto-scaling-group-name "$ASG_NAME" \
            --region "$AWS_REGION" 2>&1)
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Instance refresh cancellation initiated${NC}"
            
            # Wait for cancellation to complete
            echo -e "${BLUE}Waiting for cancellation to complete...${NC}"
            local wait_count=0
            while [ $wait_count -lt 30 ]; do
                local status
                status=$(aws autoscaling describe-instance-refreshes \
                    --auto-scaling-group-name "$ASG_NAME" \
                    --region "$AWS_REGION" \
                    --query 'InstanceRefreshes[0].Status' \
                    --output text 2>/dev/null)
                
                if [ "$status" = "Cancelled" ]; then
                    echo -e "${GREEN}✓ Instance refresh successfully cancelled${NC}"
                    return 0
                elif [ "$status" = "Successful" ]; then
                    echo -e "${GREEN}✓ Instance refresh completed before cancellation${NC}"
                    return 0
                fi
                
                echo -e "${BLUE}Status: $status - waiting...${NC}"
                sleep 5
                wait_count=$((wait_count + 1))
            done
            
            echo -e "${RED}Warning: Cancellation took longer than expected. Proceeding anyway...${NC}"
            return 0
        else
            echo -e "${RED}Failed to cancel instance refresh: $cancel_result${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}No active instance refresh found (Status: $current_status)${NC}"
        return 0
    fi
}

# Function to start new instance refresh
start_instance_refresh() {
    echo -e "${GREEN}Starting new instance refresh...${NC}"
    
    local refresh_result
    refresh_result=$(aws autoscaling start-instance-refresh \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$AWS_REGION" \
        --preferences '{
            "InstanceWarmup": 300,
            "MinHealthyPercentage": 50,
            "SkipMatching": false
        }' 2>&1)
    
    if [ $? -eq 0 ]; then
        local refresh_id
        refresh_id=$(echo "$refresh_result" | jq -r '.InstanceRefreshId // "Unknown"')
        echo -e "${GREEN}✓ New instance refresh started successfully${NC}"
        echo -e "${BLUE}Refresh ID: $refresh_id${NC}"
        echo ""
        
        # Show initial status
        echo -e "${CYAN}=== Initial Status ===${NC}"
        check_refresh_status
        return 0
    else
        echo -e "${RED}Failed to start instance refresh: $refresh_result${NC}"
        return 1
    fi
}

# Function to handle cancel and restart
cancel_and_restart() {
    echo -e "${CYAN}=== Cancel and Restart Instance Refresh ===${NC}"
    echo ""
    
    # Cancel current refresh
    if cancel_instance_refresh; then
        echo ""
        # Start new refresh
        start_instance_refresh
    else
        echo -e "${RED}Failed to cancel current refresh. Aborting restart.${NC}"
        exit 1
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 [options] [environment] [project_name] [aws_region] [watch]"
    echo ""
    echo "Options:"
    echo "  --cancel-and-restart    Cancel current instance refresh and start a new one"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Arguments:"
    echo "  environment   Environment name (default: $DEFAULT_ENVIRONMENT)"
    echo "  project_name  Project name (default: $DEFAULT_PROJECT_NAME)"
    echo "  aws_region    AWS region (default: $DEFAULT_REGION)"
    echo "  watch         Set to 'watch' for continuous monitoring"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Check current status"
    echo "  $0 production                         # Check production environment"
    echo "  $0 staging dbservice-test ap-south-1  # Full specification"
    echo "  $0 watch                              # Continuous monitoring"
    echo "  $0 --cancel-and-restart               # Cancel current and start new refresh"
    echo "  $0 --cancel-and-restart production    # Cancel and restart for production"
    echo ""
}

# Function for watch mode
watch_refresh() {
    echo -e "${GREEN}Starting continuous monitoring (Ctrl+C to stop)...${NC}"
    echo ""
    
    while true; do
        # Clear screen for better readability
        clear
        echo -e "${BLUE}=== Instance Refresh Status Check (Watch Mode) ===${NC}"
        echo -e "${BLUE}ASG Name: ${ASG_NAME}${NC}"
        echo -e "${BLUE}Region: ${AWS_REGION}${NC}"
        echo -e "${BLUE}Last Updated: $(date)${NC}"
        echo ""
        
        # Check status
        local current_status
        current_status=$(check_refresh_status)
        
        # Check if refresh is complete
        if [ "$current_status" = "Successful" ] || [ "$current_status" = "Failed" ] || [ "$current_status" = "Cancelled" ]; then
            echo -e "${GREEN}Instance refresh completed with status: $current_status${NC}"
            echo -e "${GREEN}Monitoring stopped.${NC}"
            break
        fi
        
        echo -e "${BLUE}Next update in 30 seconds... (Ctrl+C to stop)${NC}"
        sleep 30
    done
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize variables
    initialize
    
    echo -e "${GREEN}Checking AWS credentials...${NC}"
    check_aws_credentials
    
    if [ "$CANCEL_AND_RESTART" = true ]; then
        cancel_and_restart
    elif [ "$WATCH_MODE" = true ]; then
        watch_refresh
    else
        check_refresh_status
    fi
}

# Run main function
main "$@"
