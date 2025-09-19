# AlboCarRide Database Migration Guide

This guide explains how to run the database migrations for the AlboCarRide application, including the new driver verification and ride offer negotiation features.

## 📋 What's New

The following new features have been implemented:

### 1. Driver Document Verification System
- **Driver Documents Table**: Stores driver verification documents (license, registration, insurance, photos)
- **Document Upload Service**: Handles file compression and Supabase storage integration
- **Verification Page UI**: Complete interface for document capture and upload

### 2. Ride Offer Negotiation System
- **Ride Offers Table**: Manages ride offers between customers and drivers
- **Atomic RPC Function**: Race-condition-free offer acceptance (`accept_offer_atomic`)
- **RideNegotiationService**: Comprehensive service for offer management
- **OfferBoard Widget**: Real-time display of ride offers with accept/reject/counter functionality

### 3. Enhanced Driver Homepage
- Online/Offline toggle with real-time status updates
- Integrated OfferBoard for managing incoming ride requests
- Visual indicators for driver status

## 🚀 Running Migrations

### Prerequisites
- PostgreSQL client (`psql`) installed
- DATABASE_URL environment variable set with your PostgreSQL connection string
- Supabase project with proper permissions

### Method 1: Using Scripts (Recommended)

#### Linux/macOS
```bash
# Make the script executable
chmod +x scripts/run_migrations.sh

# Set your database URL
export DATABASE_URL="postgresql://username:password@hostname:port/database"

# Run migrations
./scripts/run_migrations.sh
```

#### Windows
```batch
# Set your database URL
set DATABASE_URL="postgresql://username:password@hostname:port/database"

# Run migrations
scripts\run_migrations.bat
```

### Method 2: Manual Execution

1. **Apply main schema**:
   ```bash
   psql "your_connection_string" -f database_schema.sql
   ```

2. **Apply new migrations**:
   ```bash
   psql "your_connection_string" -f db/migrations/20250919_create_driver_documents_and_ride_offers.sql
   ```

## ✅ Validation Checklist

After running migrations, verify the following:

### Database Structure Validation
- [ ] `driver_documents` table exists with correct columns
- [ ] `ride_offers` table exists with correct columns  
- [ ] `accept_offer_atomic` RPC function is created
- [ ] All indexes and constraints are properly applied

### Functionality Testing
- [ ] Driver can upload documents through VerificationPage
- [ ] Documents are stored in Supabase storage bucket 'driver-documents'
- [ ] Ride offers can be created and managed via RideNegotiationService
- [ ] OfferBoard displays offers in real-time
- [ ] Atomic offer acceptance prevents race conditions
- [ ] Driver online/offline status updates correctly

### Integration Testing
1. **Driver Registration Flow**:
   - Complete phone verification
   - Navigate to verification page
   - Upload required documents
   - Verify documents are stored and status updates

2. **Ride Offer Flow**:
   - Driver goes online
   - Create test ride offer (simulate customer request)
   - Verify offer appears in OfferBoard
   - Test accept/reject/counter functionality
   - Verify atomic operation prevents duplicate accepts

## 🔧 Troubleshooting

### Common Issues

1. **Permission Errors**:
   - Ensure database user has CREATE TABLE and EXECUTE permissions
   - Verify RLS policies allow necessary operations

2. **Connection Issues**:
   - Check DATABASE_URL format
   - Verify network connectivity to database

3. **Migration Errors**:
   - Check if tables already exist (may need to drop first in development)
   - Verify SQL syntax compatibility with your PostgreSQL version

### Debugging Tips

- Enable verbose output by adding `-v` flag to psql commands
- Check Supabase logs for RPC function errors
- Use Supabase dashboard to verify table structures

## 📊 Database Schema Changes

### New Tables

#### driver_documents
```sql
CREATE TABLE driver_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN ('license', 'registration', 'insurance', 'photo')),
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER,
    mime_type VARCHAR(100),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_by UUID REFERENCES profiles(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### ride_offers
```sql
CREATE TABLE ride_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    driver_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    pickup_location TEXT NOT NULL,
    destination TEXT NOT NULL,
    proposed_price DECIMAL(10, 2) NOT NULL,
    counter_price DECIMAL(10, 2),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'countered', 'expired')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_active_offer UNIQUE (customer_id, driver_id, status) WHERE status = 'pending'
);
```

### New RPC Function

#### accept_offer_atomic
Atomic function that ensures only one driver can accept an offer at a time, preventing race conditions.

## 🎯 Next Steps

After successful migration validation:

1. **Test Thoroughly**: Run comprehensive tests on all new features
2. **Monitor Performance**: Watch for any performance issues with real-time updates
3. **User Training**: Ensure drivers understand the new verification process
4. **Backup**: Create database backup before going to production

## 📞 Support

If you encounter issues:
1. Check this guide for troubleshooting tips
2. Verify your database connection settings
3. Ensure all prerequisite software is installed
4. Consult Supabase documentation for specific errors

---

**Happy Driving! 🚗💨**