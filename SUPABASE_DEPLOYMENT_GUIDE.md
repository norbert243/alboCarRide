# Supabase SQL Deployment Guide

## Connection Issue Solution

The error "connection string missing" indicates you need to connect to your Supabase database. Here are the ways to execute the SQL script:

## Method 1: Supabase Dashboard (Recommended)

1. **Go to your Supabase Dashboard**
   - Navigate to: `https://supabase.com/dashboard/project/[YOUR_PROJECT_ID]`

2. **Open SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Create a new query

3. **Execute the Script**
   - Copy and paste the contents of `telemetry_schema_corrected.sql`
   - Click "Run" to execute

## Method 2: Command Line (if you have connection string)

If you have your connection string, you can use `psql`:

```bash
# Set your connection string as environment variable
export DATABASE_URL="postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres"

# Execute the SQL file
psql $DATABASE_URL -f telemetry_schema_corrected.sql
```

## Method 3: Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref [YOUR_PROJECT_ID]

# Execute SQL file
supabase db push telemetry_schema_corrected.sql
```

## Method 4: Split into Smaller Chunks

If the full script is too large, execute it in sections:

### Section 1: Tables and Indexes
```sql
-- Copy just the CREATE TABLE and CREATE INDEX statements
-- from telemetry_schema_corrected.sql
```

### Section 2: Functions
```sql
-- Copy just the CREATE OR REPLACE FUNCTION statements
```

### Section 3: Security and Permissions
```sql
-- Copy the RLS policies and GRANT statements
```

## Verification Steps

After executing the script, verify it worked:

1. **Check Tables Exist**
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('telemetry_logs', 'telemetry_aggregates');
```

2. **Check Functions Exist**
```sql
SELECT proname FROM pg_proc 
WHERE proname IN ('upload_telemetry_event', 'record_telemetry_batch', 'get_driver_dashboard');
```

3. **Test Functions**
```sql
-- Test with a valid profile ID from your database
SELECT public.get_driver_dashboard('2c1454d6-a53a-40ab-b3d9-2d367a8eab57');
```

## Important Notes

### Connection String Format
Your Supabase connection string should look like:
```
postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres
```

### Finding Your Project Details
- **Project ID/Ref**: Found in your Supabase project URL
- **Password**: Your database password (set during project creation)
- **Host**: `db.[project-ref].supabase.co`

### Security Reminder
- Never commit connection strings to version control
- Use environment variables for sensitive information
- The corrected script uses proper RLS policies for security

## Troubleshooting

### Common Issues:

1. **"Permission denied"**
   - Ensure you're using the service_role key for administrative operations
   - Check that your user has necessary permissions

2. **"Table already exists"**
   - The script uses `CREATE TABLE IF NOT EXISTS` so this should be safe
   - If tables exist, they won't be recreated

3. **"Function already exists"**
   - The script uses `CREATE OR REPLACE FUNCTION` so functions will be updated

4. **Connection timeout**
   - Try executing in smaller chunks
   - Use the Supabase dashboard for large scripts

## Success Indicators

After successful execution, you should see:
- Tables `telemetry_logs` and `telemetry_aggregates` created
- Functions `upload_telemetry_event`, `record_telemetry_batch`, and `get_driver_dashboard` created
- RLS policies applied
- No error messages in the execution log

The Driver Dashboard v2 should now work correctly with the telemetry system in place.