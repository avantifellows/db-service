#!/bin/bash
# shellcheck disable=SC2153

# Enhanced Database Fetch Script with Environment Variables
# This script fetches data from production/staging and restores to local/staging database

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
# shellcheck source=/dev/null
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
# Set default values
LOCAL_DB_PORT=${LOCAL_DB_PORT:-5432}
DUMP_FILE=${DUMP_FILE:-dump.sql}
TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT:-local}
STAGING_EXCLUDED_TABLE_DATA=(public.session public.session_occurrence public.group_session public.user_session)

# Validate source environment and set database credentials
if [ "$FETCH_ENVIRONMENT" == "production" ]; then
    echo -e "${YELLOW}🏭 Using PRODUCTION source environment${NC}"
    check_required_var "PROD_DB_HOST" "$PROD_DB_HOST"
    check_required_var "PROD_DB_NAME" "$PROD_DB_NAME"
    check_required_var "PROD_DB_USER" "$PROD_DB_USER"
    check_required_var "PROD_DB_PASSWORD" "$PROD_DB_PASSWORD"
    check_required_var "PROD_DB_PORT" "$PROD_DB_PORT"
    
    SOURCE_DB_HOST=$PROD_DB_HOST
    SOURCE_DB_NAME=$PROD_DB_NAME
    SOURCE_DB_USER=$PROD_DB_USER
    SOURCE_DB_PASSWORD=$PROD_DB_PASSWORD
    SOURCE_DB_PORT=$PROD_DB_PORT
    
elif [ "$FETCH_ENVIRONMENT" == "staging" ]; then
    echo -e "${YELLOW}🧪 Using STAGING source environment${NC}"
    check_required_var "STAGING_DB_HOST" "$STAGING_DB_HOST"
    check_required_var "STAGING_DB_NAME" "$STAGING_DB_NAME"
    check_required_var "STAGING_DB_USER" "$STAGING_DB_USER"
    check_required_var "STAGING_DB_PASSWORD" "$STAGING_DB_PASSWORD"
    check_required_var "STAGING_DB_PORT" "$STAGING_DB_PORT"
    
    SOURCE_DB_HOST=$STAGING_DB_HOST
    SOURCE_DB_NAME=$STAGING_DB_NAME
    SOURCE_DB_USER=$STAGING_DB_USER
    SOURCE_DB_PASSWORD=$STAGING_DB_PASSWORD
    SOURCE_DB_PORT=$STAGING_DB_PORT
    
else
    echo -e "${RED}❌ Error: Invalid FETCH_ENVIRONMENT '$FETCH_ENVIRONMENT'${NC}"
    echo -e "${YELLOW}💡 FETCH_ENVIRONMENT must be either 'production' or 'staging'${NC}"
    exit 1
fi

# Validate target environment and set database credentials
if [ "$TARGET_ENVIRONMENT" == "local" ]; then
    echo -e "${YELLOW}💻 Using LOCAL target environment${NC}"
    check_required_var "LOCAL_DB_HOST" "$LOCAL_DB_HOST"
    check_required_var "LOCAL_DB_NAME" "$LOCAL_DB_NAME"
    check_required_var "LOCAL_DB_USER" "$LOCAL_DB_USER"
    check_required_var "LOCAL_DB_PASSWORD" "$LOCAL_DB_PASSWORD"

    TARGET_DB_HOST=$LOCAL_DB_HOST
    TARGET_DB_NAME=$LOCAL_DB_NAME
    TARGET_DB_USER=$LOCAL_DB_USER
    TARGET_DB_PASSWORD=$LOCAL_DB_PASSWORD
    TARGET_DB_PORT=$LOCAL_DB_PORT

elif [ "$TARGET_ENVIRONMENT" == "staging" ]; then
    if [ "$FETCH_ENVIRONMENT" != "production" ]; then
        echo -e "${RED}❌ Error: Staging target can only sync from production${NC}"
        echo -e "${YELLOW}💡 Set FETCH_ENVIRONMENT=production and TARGET_ENVIRONMENT=staging${NC}"
        exit 1
    fi

    echo -e "${YELLOW}🧪 Using STAGING target environment${NC}"
    check_required_var "STAGING_DB_HOST" "$STAGING_DB_HOST"
    check_required_var "STAGING_DB_NAME" "$STAGING_DB_NAME"
    check_required_var "STAGING_DB_USER" "$STAGING_DB_USER"
    check_required_var "STAGING_DB_PASSWORD" "$STAGING_DB_PASSWORD"
    check_required_var "STAGING_DB_PORT" "$STAGING_DB_PORT"

    TARGET_DB_HOST=$STAGING_DB_HOST
    TARGET_DB_NAME=$STAGING_DB_NAME
    TARGET_DB_USER=$STAGING_DB_USER
    TARGET_DB_PASSWORD=$STAGING_DB_PASSWORD
    TARGET_DB_PORT=$STAGING_DB_PORT
    echo -e "${YELLOW}⏭️  Staging sync will skip data for session tables${NC}"

elif [ "$TARGET_ENVIRONMENT" == "production" ]; then
    echo -e "${RED}❌ Error: Production cannot be used as a sync target${NC}"
    exit 1

else
    echo -e "${RED}❌ Error: Invalid TARGET_ENVIRONMENT '$TARGET_ENVIRONMENT'${NC}"
    echo -e "${YELLOW}💡 TARGET_ENVIRONMENT must be either 'local' or 'staging'${NC}"
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
echo -e "${YELLOW}⚠️  WARNING: This will completely replace your $TARGET_ENVIRONMENT database!${NC}"
echo -e "${BLUE}📊 Source: $FETCH_ENVIRONMENT ($SOURCE_DB_HOST:$SOURCE_DB_PORT/$SOURCE_DB_NAME)${NC}"
echo -e "${BLUE}🎯 Target: $TARGET_ENVIRONMENT ($TARGET_DB_HOST:$TARGET_DB_PORT/$TARGET_DB_NAME)${NC}"
echo ""
if [ "$TARGET_ENVIRONMENT" == "staging" ]; then
    read -p "Type 'SYNC STAGING' to continue: " -r
    if [ "$REPLY" != "SYNC STAGING" ]; then
        echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
        exit 0
    fi
else
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🚀 Starting database fetch process...${NC}"

# Step 1: Fetch data dump
echo -e "${BLUE}📥 Fetching data from $FETCH_ENVIRONMENT database...${NC}"
PG_DUMP_ARGS=(
    --host="$SOURCE_DB_HOST" \
    --port="$SOURCE_DB_PORT" \
    --username="$SOURCE_DB_USER" \
    --dbname="$SOURCE_DB_NAME" \
    --file="$SCRIPT_DIR/$DUMP_FILE" \
    --verbose
)

if [ "$TARGET_ENVIRONMENT" == "staging" ]; then
    for table in "${STAGING_EXCLUDED_TABLE_DATA[@]}"; do
        PG_DUMP_ARGS+=(--exclude-table-data="$table")
    done
fi

if PGPASSWORD="$SOURCE_DB_PASSWORD" "$PG_DUMP_PATH" "${PG_DUMP_ARGS[@]}"; then
    echo -e "${GREEN}✅ Data dump fetched successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to fetch data dump${NC}"
    echo -e "${YELLOW}💡 Target database remains unchanged${NC}"
    exit 1
fi

# Verify the dump file exists and has content
if [ ! -s "$SCRIPT_DIR/$DUMP_FILE" ]; then
    echo -e "${RED}❌ Error: Dump file is empty or missing${NC}"
    echo -e "${YELLOW}💡 Target database remains unchanged${NC}"
    rm -f "$SCRIPT_DIR/$DUMP_FILE"
    exit 1
fi

echo -e "${GREEN}✅ Dump file validated ($(du -h "$SCRIPT_DIR/$DUMP_FILE" | cut -f1))${NC}"

# Step 2: NOW clear target database (only after successful fetch)
echo -e "${BLUE}🧹 Clearing $TARGET_ENVIRONMENT database...${NC}"
if PGPASSWORD="$TARGET_DB_PASSWORD" "$PSQL_PATH" \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --command="DROP SCHEMA public CASCADE; CREATE SCHEMA public;" \
    --quiet; then
    echo -e "${GREEN}✅ Target database cleared${NC}"
else
    echo -e "${RED}❌ Error: Failed to clear target database${NC}"
    echo -e "${YELLOW}💡 Dump file saved at: $SCRIPT_DIR/$DUMP_FILE${NC}"
    echo -e "${YELLOW}💡 You can manually restore it later${NC}"
    exit 1
fi

# Step 3: Restore to target database
echo -e "${BLUE}📤 Restoring data to $TARGET_ENVIRONMENT database...${NC}"
if PGPASSWORD="$TARGET_DB_PASSWORD" "$PSQL_PATH" \
    --host="$TARGET_DB_HOST" \
    --port="$TARGET_DB_PORT" \
    --username="$TARGET_DB_USER" \
    --dbname="$TARGET_DB_NAME" \
    --file="$SCRIPT_DIR/$DUMP_FILE" \
    --quiet; then
    echo -e "${GREEN}✅ Data restored successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to restore data${NC}"
    echo -e "${YELLOW}💡 WARNING: Target database may be in an inconsistent state${NC}"
    echo -e "${YELLOW}💡 Dump file saved at: $SCRIPT_DIR/$DUMP_FILE${NC}"
    exit 1
fi

# Step 4: Cleanup
echo -e "${BLUE}🧹 Cleaning up temporary files...${NC}"
rm -f "$SCRIPT_DIR/$DUMP_FILE"
echo -e "${GREEN}✅ Cleanup complete${NC}"

echo ""
echo -e "${GREEN}🎉 Database fetch completed successfully!${NC}"
echo -e "${BLUE}📊 Your $TARGET_ENVIRONMENT database now contains data from $FETCH_ENVIRONMENT${NC}"
echo ""
