#!/bin/bash

# Install PostgreSQL client tools (only needed if not already installed)
# sudo apt-get install postgresql-client

# Environment (production or staging)
environment="production"  # Change this to "staging" if needed

# Database credentials for production
production_db_host="xxx.rds.amazonaws.com"
production_db_name="xxx"
production_db_user="postgres"
production_db_password="xxx"
production_db_port="1357"

# Database credentials for staging
staging_db_host="xxx-staging.rds.amazonaws.com"
staging_db_name="xxx_staging"
staging_db_user="postgres"
staging_db_password="xxx"
staging_db_port="1357"

# Local database credentials
local_db_host="localhost"
local_db_name="dbservice_dev"
local_db_user="postgres"
local_db_password="postgres"

# Dump file name
dump_file="dump.sql"

# Set database credentials based on the environment
if [ "$environment" == "production" ]; then
    db_host=$production_db_host
    db_name=$production_db_name
    db_user=$production_db_user
    db_password=$production_db_password
    db_port=$production_db_port
elif [ "$environment" == "staging" ]; then
    db_host=$staging_db_host
    db_name=$staging_db_name
    db_user=$staging_db_user
    db_password=$staging_db_password
    db_port=$staging_db_port
else
    echo "Error: Invalid environment specified. Use 'production' or 'staging'."
    exit 1
fi

# Find the location of pg_dump and psql executables
pg_dump_path=$(which pg_dump)
psql_path=$(which psql)

# Remove all existing tables from the local database
echo "Removing existing tables from local database..."
PGPASSWORD="$local_db_password" "$psql_path" --host="$local_db_host" --port=5432 --username="$local_db_user" --dbname="$local_db_name" --command="DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Fetch the data dump from the specified environment database
echo "Fetching data dump from $environment database..."
PGPASSWORD="$db_password" "$pg_dump_path" --host="$db_host" --port="$db_port" --username="$db_user" --dbname="$db_name" --file="$dump_file"
if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch data dump from $environment database"
  exit 1
fi

# Restore the dump file to the local database
echo "Restoring data dump to local database..."
PGPASSWORD="$local_db_password" "$psql_path" --host="$local_db_host" --port=5432 --username="$local_db_user" --dbname="$local_db_name" --file="$dump_file"
if [ $? -ne 0 ]; then
  echo "Error: Failed to restore data dump to local database"
  exit 1
fi

# Remove the dump file
echo "Cleaning up..."
rm "$dump_file"
echo "Database restored successfully."
