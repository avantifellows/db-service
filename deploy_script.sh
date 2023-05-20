#!/bin/bash

# Pull the latest code
git pull origin develop

# Install dependencies
mix deps.get

# Compile assets
mix phx.digest

# Migrate the database
mix ecto.migrate

# Restart the server
MIX_ENV=prod mix phx.server

