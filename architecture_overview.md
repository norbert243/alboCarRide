# AlboCarRide - Synchronized Architecture Documentation (v10)

## Overview

AlboCarRide is a comprehensive ride-hailing platform built with Flutter and Supabase, featuring a modern microservices-inspired architecture with real-time capabilities, robust authentication, and comprehensive telemetry. This document represents the **fully synchronized v10 architecture** aligning RooCode's implementation with the canonical v0-v10 specification.

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Service Layer │    │  Backend Layer  │
│                 │    │                 │    │                 │
│ • Auth Wrapper  │◄──►│ • Auth Service  │◄──►│ • Supabase Auth │
│ • Customer Flow │    │ • Driver Service│    │ • PostgreSQL DB │
│ • Driver Flow   │    │ • Wallet Service│    │ • Realtime Subs │
│                 │    │ • Telemetry     │    │ • Storage       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ External Services│   │  Real-time      │    │   Monitoring    │
│                 │   │  Features       │    │                 │
│ • FCM Push      │   │ • Wallet Updates│    │ • Telemetry     │
│ • Twilio SMS    │   │ • Trip Updates  │    │ • Error Logging │
│ • Google Maps   │   │ • Push Queue    │    │ • Performance   │
└─────────────────┘   └─────────────────┘    └─────────────────┘
```

## Technology Stack

### Frontend
- **Framework**: Flutter 3.9.0+
- **State Management**: Provider + Built-in State Management
- **UI Components**: Material Design 3
- **Platforms**: Android, iOS, Web, Desktop

### Backend & Infrastructure
- **Database**: PostgreSQL (Supabase)
- **Authentication**: Supabase Auth
- **Realtime**: Supabase Realtime
- **Storage**: Supabase Storage
- **Push Notifications**: Firebase Cloud Messaging
- **SMS/OTP**: Twilio
- **Maps**: Google Maps Platform / Mapbox

### Key Dependencies
```yaml
# Core Dependencies
supabase_flutter: ^2.10.1      # Database & Auth
firebase_messaging: ^15.1.1    # Push Notifications
firebase_core: ^3.4.1          # Firebase Core
flutter_dotenv: ^5.1.0         # Environment Variables
shared_preferences: ^2.4.1     # Local Storage
flutter_secure_storage: ^9.0.0 # Secure Storage
geolocator: ^11.0.1            # Location Services
image_picker: ^1.0.4           # Camera/Gallery
provider: ^6.1.1               # State Management
```

## Database Architecture

### Core Tables

#### User Management
```sql
-- Users & Profiles
users (id, email, created_at, updated_at)
profiles (id, full_name, phone, role, avatar_url, verification_status)
customers (id, preferred_payment_method, rating, total_rides)
drivers (id, license_number, vehicle_type, is_online, is_approved, rating)
```

#### Ride Management
```sql
-- Ride Requests & Offers
ride_requests (id, rider_id, pickup_address, dropoff_address, proposed_price, status)
ride_offers (id, driver_id, request_id, offer_price, status)

-- Trips & Payments
rides (id, customer_id, driver_id, pickup_address, dropoff_address, total_price, status)
trips (id, rider_id, driver_id, request_id, offer_id, final_price, status)
payments (id, ride_id, customer_id, driver_id, amount, payment_method, status)
driver_earnings (id, driver_id, ride_id, amount, commission, net_earnings)
```

#### Real-time Features
```sql
-- Real-time Subscriptions
driver_wallets (id, driver_id, balance, updated_at)
push_notifications (id, driver_id, user_id, title, body, status, retry_count)
push_delivery_logs (id, push_id, device_token, status, details)
telemetry_logs (id, type, message, meta, timestamp, batch_id)
```

#### Driver Management
```sql
-- Driver Verification
driver_documents (id, driver_id, document_type, document_url, status)
driver_locations (id, driver_id, lat, lng, updated_at)
```

## Service Layer Architecture

### Core Services

#### 1. AuthService
- **Purpose**: Authentication and session management
- **Features**: WhatsApp-style seamless login, secure token storage, session restoration
- **Storage**: SharedPreferences + FlutterSecureStorage
- **Session Duration**: 30 days with automatic refresh

#### 2. DriverService
- **Purpose**: Driver profile and status management
- **Features**: Approval system, online status, vehicle type management
- **Integration**: Telemetry logging for all operations

#### 3. TelemetryService
- **Purpose**: Comprehensive logging and monitoring
- **Features**: Error logging, performance metrics, batch telemetry
- **Categories**: FCM, Realtime, Wallet, Trip, Session, Auth, Performance

#### 4. RealtimeWalletService
- **Purpose**: Real-time wallet balance updates
- **Features**: Supabase Realtime subscriptions, FCM token management
- **Integration**: Automatic balance updates, low balance alerts

#### 5. PushService
- **Purpose**: Push notification management
- **Features**: Delivery receipts, retry logic, delivery statistics
- **Integration**: FCM + Supabase queue system

### Service Patterns

#### Singleton Pattern
```dart
class DriverService {
  static final DriverService instance = DriverService._internal();
  DriverService._internal();
  // Service implementation
}
```

#### Factory Pattern
```dart
class RealtimeWalletService {
  static RealtimeWalletService? _instance;
  RealtimeWalletService._internal();
  
  factory RealtimeWalletService() {
    _instance ??= RealtimeWalletService._internal();
    return _instance!;
  }
}
```

## Application Flow Architecture

### Authentication Flow
```
1. App Launch → AuthWrapper
2. Check Existing Session → AuthService
3. If Valid Session → Direct to Home
4. If No Session → Role Selection
5. Phone Verification → Twilio OTP
6. Profile Creation → SignupPage
7. Role-Specific Setup → Vehicle Type (Driver) / Home (Customer)
```

### Driver Registration Flow
```
1. Phone Verification → Twilio OTP
2. Profile Creation → SignupPage
3. Vehicle Type Selection → VehicleTypeSelectionPage
4. Document Upload → VerificationPage
5. Approval Waiting → WaitingForReviewPage
6. Dashboard Access → EnhancedDriverHomePage
```

### Ride Booking Flow
```
1. Customer Request → BookRidePage
2. Driver Matching → RideMatchingService
3. Offer Creation → RideOffers
4. Trip Creation → Trips Table
5. Real-time Tracking → DriverLocationService
6. Payment Processing → PaymentService
7. Rating & Feedback → RatingService
```

## Real-time Architecture

### Subscription System
```dart
// Wallet Updates
await _realtimeWalletService.subscribeToWalletUpdates(
  driverId,
  (balance) => updateUI(balance)
);

// Driver Status Updates
final driverChanges = _supabase
    .from('drivers')
    .stream(primaryKey: ['id'])
    .eq('id', driverId);
```

### Push Notification System
```
1. Event Trigger → Database Trigger
2. Queue Push → push_notifications table
3. Worker Processing → fetch_pending_pushes()
4. FCM Delivery → Firebase Cloud Messaging
5. Delivery Receipt → push_delivery_logs
6. Status Update → mark_push_sent/delivered
```

## Security Architecture

### Row Level Security (RLS)
- **Profiles**: Users can only access their own data
- **Driver Documents**: Drivers can only manage their own documents
- **Ride Requests**: Users can only see their own requests
- **Notifications**: Users can only view their own notifications

### Secure Storage
- **Access Tokens**: FlutterSecureStorage
- **Session Data**: SharedPreferences + SecureStorage
- **Sensitive Data**: Encrypted at rest

### Authentication Security
- **Session Duration**: 30 days with refresh
- **Token Rotation**: Automatic refresh before expiry
- **Secure Logout**: Complete session cleanup

## Migration Architecture

### Versioned Migrations
- **Migration v8**: Real-time wallet + push notifications
- **Migration v9**: Enhanced queue management + delivery receipts
- **Migration v10**: Driver approval system + telemetry integration

### Safe Migration Patterns
```sql
-- Safe DROP/CREATE patterns
DROP FUNCTION IF EXISTS function_name CASCADE;
CREATE OR REPLACE FUNCTION function_name()...

-- Conditional column addition
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns...) THEN
    ALTER TABLE table_name ADD COLUMN column_name...;
  END IF;
END $$;
```

## Performance Architecture

### Database Indexing
```sql
-- Performance Indexes
CREATE INDEX idx_drivers_online_status ON drivers(is_online);
CREATE INDEX idx_ride_requests_status ON ride_requests(status);
CREATE INDEX idx_push_notifications_status ON push_notifications(status);
```

### Telemetry Batching
```dart
// Batch telemetry insertion
await TelemetryService.instance.flushTelemetry([
  {'type': 'event1', 'message': 'message1'},
  {'type': 'event2', 'message': 'message2'},
]);
```

### Real-time Optimization
- **Channel Management**: Automatic subscription cleanup
- **Connection Pooling**: Supabase client reuse
- **Event Filtering**: Targeted real-time subscriptions

## Monitoring & Observability

### Telemetry Categories
- **FCM Events**: Token registration, message delivery
- **Realtime Events**: Subscription creation, updates, errors
- **Wallet Events**: Balance changes, transactions
- **Trip Events**: Lifecycle state changes
- **Session Events**: Authentication, authorization
- **Performance Metrics**: Response times, operation durations

### Error Handling
```dart
try {
  // Operation
} catch (e, st) {
  await TelemetryService.instance.logError(
    type: 'operation_failed',
    message: 'Failed to perform operation: $e',
    stackTrace: st.toString(),
    metadata: {'context': 'additional_info'}
  );
}
```

## Deployment Architecture

### Environment Configuration
```dart
// Environment variables
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
GOOGLE_MAPS_API_KEY=your_maps_key
FIREBASE_PROJECT_ID=your_firebase_id
```

### Build Configuration
- **Android**: Gradle 8.13, Kotlin, Firebase config
- **iOS**: Swift, Firebase config, APNS setup
- **Web**: PWA capabilities, service workers

## Scalability Considerations

### Database Scaling
- **Index Optimization**: Strategic indexing for query performance
- **Partitioning**: Time-based partitioning for large tables
- **Connection Pooling**: Efficient connection management

### Application Scaling
- **Service Isolation**: Independent service components
- **Caching Strategy**: Local caching for frequently accessed data
- **Background Processing**: Offloaded to server-side workers

### Real-time Scaling
- **Channel Management**: Efficient real-time channel usage
- **Event Filtering**: Targeted subscription patterns
- **Connection Limits**: Appropriate connection pooling

This architecture provides a robust, scalable foundation for the AlboCarRide platform with comprehensive real-time capabilities, security, and monitoring.

## Synchronization Report: RooCode ↔ Canonical v0-v10

### ✅ Perfectly Aligned Components

#### System Architecture
- **Frontend Layer**: Flutter app with AuthWrapper, Customer Flow, Driver Flow
- **Service Layer**: AuthService, DriverService, WalletService, TelemetryService, RealtimeWalletService
- **Backend Layer**: Supabase Auth, PostgreSQL Database, Realtime Subscriptions, Storage Buckets
- **External Services**: Firebase Cloud Messaging, Twilio SMS, Google Maps API

#### Database Schema
- **User Management**: users, profiles, customers, drivers tables
- **Ride Management**: ride_requests, ride_offers, rides, trips, payments tables
- **Real-time Features**: driver_wallets, push_notifications, push_delivery_logs, telemetry_logs
- **Driver Management**: driver_documents, driver_locations

### 🔄 Enhanced Components for v10 Compliance

#### 1. Driver Approval System (v10)
```sql
-- drivers table enhancement
ALTER TABLE drivers ADD COLUMN is_approved boolean NOT NULL DEFAULT false;
ALTER TABLE drivers ADD COLUMN approved_at timestamptz;

-- Approval trigger and RPC
CREATE TRIGGER driver_approval_after_update
  AFTER UPDATE ON drivers
  FOR EACH ROW
  WHEN (OLD.is_approved IS DISTINCT FROM NEW.is_approved)
EXECUTE FUNCTION driver_approval_after_update_fn();

CREATE FUNCTION set_driver_approval(p_driver_id uuid, p_is_approved boolean)
RETURNS void SECURITY DEFINER;
```

#### 2. Enhanced Telemetry with Batch Processing (v9)
```sql
-- Telemetry queue for batch processing
CREATE TABLE telemetry_queue (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id uuid,
  type text NOT NULL,
  message text NOT NULL,
  meta jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- Batch telemetry function
CREATE FUNCTION flush_telemetry(p_payloads jsonb[])
RETURNS integer SECURITY DEFINER;
```

#### 3. Push Notification Delivery Receipts (v9)
```sql
-- Enhanced push delivery tracking
CREATE TABLE push_delivery_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  push_id uuid REFERENCES push_notifications(id),
  device_token text,
  status text CHECK (status IN ('delivered','failed','opened','clicked')),
  details jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Delivery receipt function
CREATE FUNCTION record_delivery_receipt(
  p_push_id uuid,
  p_device_token text,
  p_status text,
  p_details jsonb DEFAULT '{}'
) RETURNS void SECURITY DEFINER;
```

#### 4. Service Layer Enhancements

**SessionService** (Missing from RooCode doc):
```dart
class SessionService {
  // Persistent session management
  Future<void> initialize();
  Future<void> restoreSession();
  Future<void> clearSession();
}
```

**PushWorkerClient** (v9 Retry Worker):
```dart
class PushWorkerClient {
  // Server-side push processing
  Future<List<PushNotification>> fetchPendingPushes();
  Future<void> markPushSent(String pushId);
  Future<void> markPushFailed(String pushId, String error);
}
```

**WalletService** (Renamed from RealtimeWalletService for consistency):
```dart
class WalletService {
  static final WalletService instance = WalletService._internal();
  WalletService._internal();
  // Real-time wallet functionality
}
```

### 🎯 Application Flow Updates

#### Driver Registration Flow (v10 Enhanced)
```
1. Phone Verification → Twilio OTP
2. Profile Creation → SignupPage
3. Vehicle Type Selection → VehicleTypeSelectionPage
4. Document Upload → VerificationPage
5. Approval Waiting → WaitingForReviewPage
6. ✅ Once approved (is_approved = true) → EnhancedDriverHomePage unlocked
```

#### Approval-Based UI Gating
```dart
// EnhancedDriverHomePage approval check
Future<bool> canGoOnline(String driverId) async {
  final driver = await DriverService.instance.fetchDriverProfile(driverId);
  return driver?.isApproved == true; // v10 requirement
}
```

### 📊 Performance Optimizations

#### Database Indexes for v10
```sql
-- Driver approval queries
CREATE INDEX idx_drivers_approval_status ON drivers(is_approved);
CREATE INDEX idx_drivers_approved_at ON drivers(approved_at);

-- Telemetry optimization
CREATE INDEX idx_telemetry_logs_type ON telemetry_logs(type);
CREATE INDEX idx_telemetry_queue_batch_id ON telemetry_queue(batch_id);
CREATE INDEX idx_telemetry_queue_processed_at ON telemetry_queue(processed_at);
```

#### Batch Telemetry Integration
```dart
// Enhanced TelemetryService with batch support
class TelemetryService {
  Future<void> flushTelemetryBatch(List<Map<String, dynamic>> events) async {
    // Write to telemetry_queue for batch processing
    await _client.rpc('flush_telemetry', params: {'p_payloads': events});
  }
}
```

### 🔒 Security Enhancements

#### RLS Policies for v10 Tables
```sql
-- drivers table RLS
CREATE POLICY drivers_select_owner ON drivers FOR SELECT
  USING (auth.uid() = id OR auth.role() = 'service_role');

-- telemetry_queue RLS (service role only)
CREATE POLICY telemetry_queue_service_only ON telemetry_queue
  FOR ALL USING (auth.role() = 'service_role');
```

### 🚀 Migration Architecture (v8-v10)

| Version | Purpose | Key Components |
|---------|---------|----------------|
| **v8** | Real-time wallet + push queue | `enqueue_push_notification()`, wallet triggers |
| **v9** | Queue delivery receipts + batch telemetry | `push_delivery_logs`, `telemetry_queue`, `record_delivery_receipt()` |
| **v10** | Driver approval system | `is_approved`, `set_driver_approval()`, approval triggers |

### 📈 Monitoring & Observability (v10 Enhanced)

#### Telemetry Categories
- **FCM Events**: Token registration, message delivery, delivery receipts
- **Realtime Events**: Subscription creation, updates, errors
- **Wallet Events**: Balance changes, transactions, low balance alerts
- **Trip Events**: Lifecycle state changes, pricing updates
- **Session Events**: Authentication, authorization, session restoration
- **Approval Events**: Driver approval state changes (v10)
- **Performance Metrics**: Response times, operation durations, batch processing

#### Enhanced Error Handling with Batch Support
```dart
try {
  // Operation
} catch (e, st) {
  await TelemetryService.instance.logError(
    type: 'operation_failed',
    message: 'Failed to perform operation: $e',
    stackTrace: st.toString(),
    metadata: {'context': 'additional_info'}
  );
  
  // Batch telemetry for performance
  await TelemetryService.instance.flushTelemetryBatch([
    {'type': 'error_batch', 'message': 'Batch error processing'},
    // Additional batch events...
  ]);
}
```

## Deployment Configuration (v10)

### Environment Variables
```dart
// Required for v10 functionality
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key  // Required for admin approval RPC
GOOGLE_MAPS_API_KEY=your_maps_key
FIREBASE_PROJECT_ID=your_firebase_id
```

## Conclusion

This synchronized v10 architecture provides a **production-ready foundation** for AlboCarRide with:

- ✅ **Complete v0-v10 feature alignment**
- ✅ **Enhanced driver approval system**
- ✅ **Batch telemetry processing**
- ✅ **Push delivery receipt tracking**
- ✅ **Performance-optimized database schema**
- ✅ **Comprehensive security and monitoring**
- ✅ **Scalable real-time capabilities**

The architecture ensures perfect synchronization between RooCode's implementation and the canonical v0-v10 specification, providing a robust, scalable platform for ride-hailing operations.