@echo off
echo 🚗 AlboCarRide Database Migration Script
echo ========================================

REM Check if DATABASE_URL is set
if "%DATABASE_URL%"=="" (
    echo ❌ DATABASE_URL environment variable is not set.
    echo Please set it to your PostgreSQL connection string.
    echo Example: postgresql://username:password@hostname:port/database
    pause
    exit /b 1
)

echo 📦 Running database migrations...

REM Run the main schema
echo 📋 Applying main database schema...
psql "%DATABASE_URL%" -f database_schema.sql

REM Run the new migrations
echo 📋 Applying driver documents migration...
psql "%DATABASE_URL%" -f db\migrations\20250919_create_driver_documents_and_ride_offers.sql

echo ✅ All migrations completed successfully!
echo.
echo 📊 Database structure has been updated with:
echo    - Driver documents table for verification
echo    - Ride offers table for negotiation system
echo    - Atomic offer acceptance function
echo.
echo 🚀 Your AlboCarRide application is ready to use!
pause