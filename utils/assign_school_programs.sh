#!/bin/bash

# Assign School Programs Script
# This script assigns program_ids to schools based on school category and code.
# It looks up program IDs dynamically by name, so it works across environments.
#
# NOTE: This script has likely already been run on production/staging.
# Running it again is safe (idempotent) but unnecessary.

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

echo -e "${BLUE}School Program Assignment Utility${NC}"
echo "======================================="

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure your database credentials:${NC}"
    echo "   cp $SCRIPT_DIR/.env.example $ENV_FILE"
    exit 1
fi

# Load environment variables
echo -e "${BLUE}Loading configuration from .env...${NC}"
source "$ENV_FILE"

# Function to check if a variable is set and not empty
check_required_var() {
    local var_name=$1
    local var_value=$2

    if [ -z "$var_value" ]; then
        echo -e "${RED}Error: Required environment variable '$var_name' is not set or is empty${NC}"
        exit 1
    fi
}

# Parse command line arguments
TARGET_ENV=${1:-local}

case "$TARGET_ENV" in
    production)
        echo -e "${YELLOW}Targeting PRODUCTION environment${NC}"
        check_required_var "PROD_DB_HOST" "$PROD_DB_HOST"
        check_required_var "PROD_DB_NAME" "$PROD_DB_NAME"
        check_required_var "PROD_DB_USER" "$PROD_DB_USER"
        check_required_var "PROD_DB_PASSWORD" "$PROD_DB_PASSWORD"
        check_required_var "PROD_DB_PORT" "$PROD_DB_PORT"

        DB_HOST=$PROD_DB_HOST
        DB_NAME=$PROD_DB_NAME
        DB_USER=$PROD_DB_USER
        DB_PASSWORD=$PROD_DB_PASSWORD
        DB_PORT=$PROD_DB_PORT
        ;;
    staging)
        echo -e "${YELLOW}Targeting STAGING environment${NC}"
        check_required_var "STAGING_DB_HOST" "$STAGING_DB_HOST"
        check_required_var "STAGING_DB_NAME" "$STAGING_DB_NAME"
        check_required_var "STAGING_DB_USER" "$STAGING_DB_USER"
        check_required_var "STAGING_DB_PASSWORD" "$STAGING_DB_PASSWORD"
        check_required_var "STAGING_DB_PORT" "$STAGING_DB_PORT"

        DB_HOST=$STAGING_DB_HOST
        DB_NAME=$STAGING_DB_NAME
        DB_USER=$STAGING_DB_USER
        DB_PASSWORD=$STAGING_DB_PASSWORD
        DB_PORT=$STAGING_DB_PORT
        ;;
    local)
        echo -e "${YELLOW}Targeting LOCAL environment${NC}"
        check_required_var "LOCAL_DB_HOST" "$LOCAL_DB_HOST"
        check_required_var "LOCAL_DB_NAME" "$LOCAL_DB_NAME"
        check_required_var "LOCAL_DB_USER" "$LOCAL_DB_USER"
        check_required_var "LOCAL_DB_PASSWORD" "$LOCAL_DB_PASSWORD"

        DB_HOST=$LOCAL_DB_HOST
        DB_NAME=$LOCAL_DB_NAME
        DB_USER=$LOCAL_DB_USER
        DB_PASSWORD=$LOCAL_DB_PASSWORD
        DB_PORT=${LOCAL_DB_PORT:-5432}
        ;;
    *)
        echo -e "${RED}Error: Invalid environment '$TARGET_ENV'${NC}"
        echo -e "${YELLOW}Usage: $0 [local|staging|production]${NC}"
        exit 1
        ;;
esac

# Check if psql is available
PSQL_PATH=$(which psql)
if [ -z "$PSQL_PATH" ]; then
    echo -e "${RED}Error: psql not found in PATH${NC}"
    echo -e "${YELLOW}Please install PostgreSQL client tools${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration validated${NC}"
echo ""

# Confirmation prompt
echo -e "${YELLOW}This will assign program_ids to schools in $TARGET_ENV:${NC}"
echo "  - JNV schools (except 8 excluded) -> JNV NVS program"
echo "  - 18 CoE schools -> JNV CoE program"
echo "  - 13 Nodal schools -> JNV Nodal program"
echo ""
echo -e "${BLUE}Target: $DB_HOST:$DB_PORT/$DB_NAME${NC}"
echo ""
read -p "Continue? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Starting program assignment...${NC}"

# Run the SQL
PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    --quiet \
    <<'EOF'

-- Step 1: Assign JNV NVS program to all JNV schools except excluded ones
-- Excluded UDISE codes: 29270124102, 29230607302, 29240101004, 29160100508,
--                       36020990151, 36130300529, 27090802602, 27080812802
UPDATE school
SET program_ids = ARRAY[(SELECT id FROM program WHERE name = 'JNV NVS')]
WHERE af_school_category = 'JNV'
  AND udise_code NOT IN (
    '29270124102', '29230607302', '29240101004', '29160100508',
    '36020990151', '36130300529', '27090802602', '27080812802'
  )
  AND EXISTS (SELECT 1 FROM program WHERE name = 'JNV NVS');

-- Step 2: Add JNV CoE program to CoE schools
-- 18 schools: 14061, 14201, 19061, 19175, 24701, 34054, 34082, 39241, 39370,
--             49037, 54059, 59204, 59324, 59525, 59526, 74034, 79012, 79019
UPDATE school
SET program_ids = array_cat(
    ARRAY[(SELECT id FROM program WHERE name = 'JNV CoE')],
    program_ids
)
WHERE code IN (
    '14061', '14201', '19061', '19175', '24701', '34054', '34082', '39241', '39370',
    '49037', '54059', '59204', '59324', '59525', '59526', '74034', '79012', '79019'
)
AND EXISTS (SELECT 1 FROM program WHERE name = 'JNV CoE');

-- Step 3: Add JNV Nodal program to Nodal schools (2025-26)
-- 13 schools: 14032, 34056, 34062, 34068, 49022, 49037, 49046, 49057, 49069,
--             59525, 59528, 69035, 69058
UPDATE school
SET program_ids = array_cat(
    ARRAY[(SELECT id FROM program WHERE name = 'JNV Nodal')],
    program_ids
)
WHERE code IN (
    '14032', '34056', '34062', '34068', '49022', '49037', '49046', '49057', '49069',
    '59525', '59528', '69035', '69058'
)
AND EXISTS (SELECT 1 FROM program WHERE name = 'JNV Nodal');

EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Program assignment completed successfully!${NC}"
else
    echo -e "${RED}Error: Failed to assign programs${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Summary of changes:${NC}"

# Show summary
PGPASSWORD="$DB_PASSWORD" "$PSQL_PATH" \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    --quiet \
    -t \
    <<'EOF'
SELECT
    'Schools with program_ids assigned: ' || COUNT(*)
FROM school
WHERE array_length(program_ids, 1) > 0;
EOF

echo ""
