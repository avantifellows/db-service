#!/bin/bash

# Enhanced Database Fetch Script with Environment Variables
# This script fetches data from production/staging and restores to local database

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo -e "${BLUE}🗄️  DB Service - Data Fetch Utility${NC}"
echo "======================================="

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Error: .env file not found at $ENV_FILE${NC}"
    echo -e "${YELLOW}💡 Please copy .env.example to .env and configure your database credentials:${NC}"
    echo "   cp $SCRIPT_DIR/.env.example $ENV_FILE"
    echo "   # Then edit $ENV_FILE with your actual credentials"
    exit 1
fi

# Load environment variables
echo -e "${BLUE}📖 Loading configuration from .env...${NC}"
source "$ENV_FILE"

# Function to check if a variable is set and not empty
check_required_var() {
    local var_name=$1
    local var_value=$2
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}❌ Error: Required environment variable '$var_name' is not set or is empty${NC}"
        echo -e "${YELLOW}💡 Please check your .env file: $ENV_FILE${NC}"
        exit 1
    fi
}

# Check required environment variables
echo -e "${BLUE}🔍 Validating configuration...${NC}"

check_required_var "FETCH_ENVIRONMENT" "$FETCH_ENVIRONMENT"
check_required_var "LOCAL_DB_HOST" "$LOCAL_DB_HOST"
check_required_var "LOCAL_DB_NAME" "$LOCAL_DB_NAME"
check_required_var "LOCAL_DB_USER" "$LOCAL_DB_USER"
check_required_var "LOCAL_DB_PASSWORD" "$LOCAL_DB_PASSWORD"

# Set default values
LOCAL_DB_PORT=${LOCAL_DB_PORT:-5432}
DUMP_FILE=${DUMP_FILE:-dump.sql}

# Validate environment and set remote database credentials
if [ "$FETCH_ENVIRONMENT" == "production" ]; then
    echo -e "${YELLOW}🏭 Using PRODUCTION environment${NC}"
    check_required_var "PROD_DB_HOST" "$PROD_DB_HOST"
    check_required_var "PROD_DB_NAME" "$PROD_DB_NAME"
    check_required_var "PROD_DB_USER" "$PROD_DB_USER"
    check_required_var "PROD_DB_PASSWORD" "$PROD_DB_PASSWORD"
    check_required_var "PROD_DB_PORT" "$PROD_DB_PORT"
    
    REMOTE_DB_HOST=$PROD_DB_HOST
    REMOTE_DB_NAME=$PROD_DB_NAME
    REMOTE_DB_USER=$PROD_DB_USER
    REMOTE_DB_PASSWORD=$PROD_DB_PASSWORD
    REMOTE_DB_PORT=$PROD_DB_PORT
    
elif [ "$FETCH_ENVIRONMENT" == "staging" ]; then
    echo -e "${YELLOW}🧪 Using STAGING environment${NC}"
    check_required_var "STAGING_DB_HOST" "$STAGING_DB_HOST"
    check_required_var "STAGING_DB_NAME" "$STAGING_DB_NAME"
    check_required_var "STAGING_DB_USER" "$STAGING_DB_USER"
    check_required_var "STAGING_DB_PASSWORD" "$STAGING_DB_PASSWORD"
    check_required_var "STAGING_DB_PORT" "$STAGING_DB_PORT"
    
    REMOTE_DB_HOST=$STAGING_DB_HOST
    REMOTE_DB_NAME=$STAGING_DB_NAME
    REMOTE_DB_USER=$STAGING_DB_USER
    REMOTE_DB_PASSWORD=$STAGING_DB_PASSWORD
    REMOTE_DB_PORT=$STAGING_DB_PORT
    
else
    echo -e "${RED}❌ Error: Invalid FETCH_ENVIRONMENT '$FETCH_ENVIRONMENT'${NC}"
    echo -e "${YELLOW}💡 FETCH_ENVIRONMENT must be either 'production' or 'staging'${NC}"
    exit 1
fi

# Check if PostgreSQL tools are available
echo -e "${BLUE}🔧 Checking PostgreSQL tools...${NC}"
PG_DUMP_PATH=$(which pg_dump)
PSQL_PATH=$(which psql)

if [ -z "$PG_DUMP_PATH" ]; then
    echo -e "${RED}❌ Error: pg_dump not found in PATH${NC}"
    echo -e "${YELLOW}💡 Please install PostgreSQL client tools${NC}"
    exit 1
fi

if [ -z "$PSQL_PATH" ]; then
    echo -e "${RED}❌ Error: psql not found in PATH${NC}"
    echo -e "${YELLOW}💡 Please install PostgreSQL client tools${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validated successfully${NC}"
echo ""

# Confirmation prompt
echo -e "${YELLOW}⚠️  WARNING: This will completely replace your local database!${NC}"
echo -e "${BLUE}📊 Source: $FETCH_ENVIRONMENT ($REMOTE_DB_HOST:$REMOTE_DB_PORT/$REMOTE_DB_NAME)${NC}"
echo -e "${BLUE}🎯 Target: $LOCAL_DB_HOST:$LOCAL_DB_PORT/$LOCAL_DB_NAME${NC}"
echo ""
read -p "Are you sure you want to continue? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🚀 Starting database fetch process...${NC}"

# Step 1: Clear local database
echo -e "${BLUE}🧹 Clearing local database...${NC}"
PGPASSWORD="$LOCAL_DB_PASSWORD" "$PSQL_PATH" \
    --host="$LOCAL_DB_HOST" \
    --port="$LOCAL_DB_PORT" \
    --username="$LOCAL_DB_USER" \
    --dbname="$LOCAL_DB_NAME" \
    --command="DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
    --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Local database cleared${NC}"
else
    echo -e "${RED}❌ Error: Failed to clear local database${NC}"
    exit 1
fi

# Step 2: Fetch data dump
echo -e "${BLUE}📥 Fetching data from $FETCH_ENVIRONMENT database...${NC}"
PGPASSWORD="$REMOTE_DB_PASSWORD" "$PG_DUMP_PATH" \
    --host="$REMOTE_DB_HOST" \
    --port="$REMOTE_DB_PORT" \
    --username="$REMOTE_DB_USER" \
    --dbname="$REMOTE_DB_NAME" \
    --file="$SCRIPT_DIR/$DUMP_FILE" \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Data dump fetched successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to fetch data dump${NC}"
    exit 1
fi

# Step 3: Restore to local database
echo -e "${BLUE}📤 Restoring data to local database...${NC}"
PGPASSWORD="$LOCAL_DB_PASSWORD" "$PSQL_PATH" \
    --host="$LOCAL_DB_HOST" \
    --port="$LOCAL_DB_PORT" \
    --username="$LOCAL_DB_USER" \
    --dbname="$LOCAL_DB_NAME" \
    --file="$SCRIPT_DIR/$DUMP_FILE" \
    --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Data restored successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to restore data${NC}"
    exit 1
fi

# Step 4: Cleanup
echo -e "${BLUE}🧹 Cleaning up temporary files...${NC}"
rm -f "$SCRIPT_DIR/$DUMP_FILE"
echo -e "${GREEN}✅ Cleanup complete${NC}"

echo ""
echo -e "${GREEN}🎉 Database fetch completed successfully!${NC}"
echo -e "${BLUE}📊 Your local database now contains data from $FETCH_ENVIRONMENT${NC}"
echo ""
