#!/bin/bash

# AlboCarRide Database Migration Script
# This script runs the database migrations for the ride-sharing application

set -e

echo "🚗 AlboCarRide Database Migration Script"
echo "========================================"

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL client (psql) is not installed. Please install it first."
    exit 1
fi

# Check for required environment variables
if [ -z "$DATABASE_URL" ]; then
    echo "❌ DATABASE_URL environment variable is not set."
    echo "Please set it to your PostgreSQL connection string."
    echo "Example: postgresql://username:password@hostname:port/database"
    exit 1
fi

echo "📦 Running database migrations..."

# Run the main schema
echo "📋 Applying main database schema..."
psql "$DATABASE_URL" -f database_schema.sql

# Run the new migrations
echo "📋 Applying driver documents migration..."
psql "$DATABASE_URL" -f db/migrations/20250919_create_driver_documents_and_ride_offers.sql

echo "✅ All migrations completed successfully!"
echo ""
echo "📊 Database structure has been updated with:"
echo "   - Driver documents table for verification"
echo "   - Ride offers table for negotiation system"
echo "   - Atomic offer acceptance function"
echo ""
echo "🚀 Your AlboCarRide application is ready to use!"