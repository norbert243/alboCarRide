# Unified Database Schema Documentation

## Overview

This document describes the **unified database schema** that exactly matches your current live Supabase database structure. This schema serves as the **single source of truth** for all database operations, migrations, and development environments.

## Schema Alignment Strategy

### ✅ **Exact Match with Live Supabase**
- **No schema changes** - This matches your production database exactly
- **Preserves existing data** - All current user data remains intact
- **Maintains compatibility** - Existing Flutter app code continues to work

### 🔑 **Key Design Decisions Preserved**

1. **Driver-Centric Document Storage**
   - `driver_documents` table uses `driver_id` (not `profile_id`)
   - Matches your existing storage bucket path structure
   - Maintains RLS policy compatibility

2. **Ride Request Structure**
   - `ride_requests` uses `rider_id` referencing `profiles` table
   - Consistent with your current app logic

3. **Dual Profile System**
   - `profiles` table for basic user info
   - Separate `customers` and `drivers` tables for role-specific data
   - Maintains your existing user management approach

## Schema Structure

### Core User Management
```sql
users (auth.users extension)
profiles (user profiles with role-based access)
customers (customer-specific data)
drivers (driver-specific data)
```

### Driver Verification System
```sql
driver_documents (verification documents)
driver_locations (real-time driver tracking)
```

### Ride Management
```sql
ride_requests (customer ride requests)
ride_offers (driver ride offers)
rides (completed and active rides)
trips (trip tracking)
```

### Payment & Analytics
```sql
payments (payment transactions)
driver_earnings (driver income tracking)
ratings (user ratings system)
notifications (user notifications)
```

## Critical Foreign Key Relationships

### User Identity Flow
```
auth.users → profiles → (customers OR drivers)
```

### Driver Document Flow
```
drivers → driver_documents → storage.objects (driver-documents bucket)
```

### Ride Request Flow
```
profiles (rider) → ride_requests → ride_offers → trips
```

## RLS Policy Alignment

### Profiles Table Policies
- Users can only view/update their own profile
- Maintains data privacy and security

### Driver Documents Policies
- Drivers can only access their own documents
- Secure document upload and retrieval

### Ride Request Policies
- Users can only manage their own ride requests
- Prevents unauthorized access to ride data

## Storage Bucket Configuration

### Existing Bucket
- **Bucket ID**: `driver-documents`
- **Status**: Already exists in your Supabase project
- **Path Structure**: `user_id/document_type/filename`

### RLS Policies for Storage
- Drivers can upload/view/update/delete only their own documents
- Matches your current document upload service implementation

## Migration Safety

### Zero-Risk Migration
This schema represents your **current production state**, so applying it is safe:

1. **No data loss** - All existing tables and data are preserved
2. **No breaking changes** - Flutter app continues to work unchanged
3. **RLS policies maintained** - Security remains intact

### Verification Steps
After applying this schema, verify:
- ✅ All existing users can log in
- ✅ Driver documents are accessible
- ✅ Ride requests function normally
- ✅ Storage bucket operations work

## Development Environment Setup

### Local Development
```bash
# Apply the unified schema to local Supabase
supabase db reset
```

### Production Environment
```bash
# This schema matches production - no changes needed
# Use for reference and documentation only
```

## Code Compatibility

### Flutter App Integration
Your existing Flutter code remains fully compatible:

- **Profile Creation**: Uses `profiles` table with UPSERT logic
- **Document Upload**: Uses `driver-documents` storage bucket
- **Session Management**: Enhanced dual-session system
- **Navigation**: Correct route names and flow

### API Endpoints
All existing Supabase API calls continue to work:
- `profiles` table queries
- `driver_documents` operations  
- `ride_requests` management
- Storage bucket file operations

## Future Development Guidelines

### Schema Changes
When modifying the database:

1. **Update this unified schema** first
2. **Test locally** with Supabase CLI
3. **Create migration files** for production
4. **Update Flutter code** accordingly

### Adding New Features
Follow the existing patterns:
- Use `profiles.id` for user identity
- Maintain RLS policies for security
- Follow established foreign key relationships

## Troubleshooting

### Common Issues

**Profile Creation Errors**
- Check `profiles_pkey` constraint
- Verify UPSERT logic in Flutter code

**Document Upload Issues**
- Confirm storage bucket exists
- Check RLS policies for `driver-documents`

**Session Problems**
- Use session debug tools to diagnose
- Verify dual-session synchronization

### Debugging Tools
- Session Debug Screen: `/session-debug`
- Database Query Logs: Supabase Dashboard
- Storage Browser: Supabase Storage interface

## Conclusion

This unified schema provides:

✅ **Exact match** with your live Supabase database  
✅ **Zero-risk** application (it's your current state)  
✅ **Full compatibility** with existing Flutter code  
✅ **Comprehensive documentation** for future development  
✅ **Security maintained** through proper RLS policies  

Use this schema as the **single source of truth** for all database-related work, ensuring consistency across all environments and preventing schema drift.

---

**Last Updated**: 2025-09-26  
**Status**: ✅ **Production Ready**  
**Environment**: Matches Live Supabase Database