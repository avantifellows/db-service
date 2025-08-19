#!/bin/bash

# DB Service - Phoenix Server Startup Script
echo "🚀 Starting DB Service Phoenix Server..."
echo "📍 Current directory: $(pwd)"
echo "🔧 Elixir version: $(elixir --version | grep Elixir)"
echo ""

# Check if PostgreSQL is running
if ! brew services list | grep -q "postgresql.*started"; then
    echo "⚠️  PostgreSQL is not running. Starting it now..."
    brew services start postgresql@16
    echo "✅ PostgreSQL started"
    echo ""
fi

# Generate Swagger documentation
echo "📚 Generating API documentation..."
mix phx.swagger.generate > /dev/null 2>&1
echo "✅ Swagger documentation generated"
echo ""

# Start the Phoenix server
echo "🌐 Starting Phoenix server on http://localhost:4000"
echo "📚 API Documentation: http://localhost:4000/docs/swagger/index.html"
echo ""
echo "Press Ctrl+C twice to stop the server"
echo "----------------------------------------"

mix phx.server
