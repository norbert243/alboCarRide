# AlboCarRide - Feature Testing Guide
**Congo Market Launch - Production Ready Testing**

---

## 🎯 TESTING CHECKLIST

### ✅ **1. EMERGENCY CONTACTS** (Priority: CRITICAL)

**Setup:**
1. Login as customer or driver
2. Navigate to Emergency Contacts page
3. Add 3 emergency contacts:
   - Contact 1 (Primary): Name, Phone (+243...), Relationship
   - Contact 2 (Secondary): Name, Phone, Relationship
   - Contact 3 (Tertiary): Name, Phone, Relationship
4. Set notification preferences (SMS, WhatsApp)

**Expected Result:**
- ✅ Maximum 3 contacts enforced
- ✅ Priority order displayed (1, 2, 3)
- ✅ Edit/delete works
- ✅ At least one notification method required

**Database Check:**
```sql
SELECT * FROM emergency_contacts WHERE user_id = 'YOUR_USER_ID';
```

---

### 🚨 **2. EMERGENCY SOS - PASSENGER** (Priority: CRITICAL)

**Test Scenario:**
1. Login as customer
2. Start a ride or navigate to home screen
3. Find the SOS button (red emergency button)
4. **HOLD** the button for 3 seconds (don't just tap)
5. Wait for vibration/feedback

**Expected Result:**
- ✅ Progress indicator fills up during 3-second hold
- ✅ SMS sent to all 3 emergency contacts automatically
- ✅ WhatsApp messages sent (if enabled)
- ✅ Message includes: "EMERGENCY ALERT from [Name] - Location: [Google Maps Link]"
- ✅ SOS incident logged in database with location

**SMS Content Check:**
```
🚨 EMERGENCY ALERT!

[Your Name] has triggered an emergency SOS alert.

Current Location:
https://www.google.com/maps?q=LATITUDE,LONGITUDE

Time: [Timestamp]
Trip ID: [If on trip]

This is an automated alert from AlboCarRide.
```

**Database Check:**
```sql
SELECT * FROM sos_incidents
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 1;
```

---

### 🚨 **3. EMERGENCY SOS - DRIVER** (Priority: CRITICAL)

**Test Scenario:**
1. Login as driver
2. **HOLD** SOS button for 3 seconds
3. Check other drivers nearby get push notification

**Expected Result:**
- ✅ All drivers within 3-5km radius get push notification
- ✅ Notification includes driver's location
- ✅ Responding drivers can view incident details
- ✅ SOS incident logged with `user_role = 'driver'`

**Database Check:**
```sql
SELECT
    id,
    user_role,
    latitude,
    longitude,
    status,
    notified_drivers,
    created_at
FROM sos_incidents
WHERE user_role = 'driver'
ORDER BY created_at DESC;
```

---

### 📍 **4. SAVED ADDRESSES** (Priority: HIGH)

**Test Scenario:**
1. Login as customer
2. Navigate to Saved Addresses page
3. Add "Home" address:
   - Label: "Home"
   - Address: [Enter full address]
   - Type: Home
   - Notes: "Main entrance"
4. Add "Work" address
5. Add custom address (e.g., "Gym")

**Expected Result:**
- ✅ Addresses saved to database
- ✅ Can edit existing addresses
- ✅ Can delete addresses
- ✅ Unique labels enforced (can't have two "Home" addresses)
- ✅ Addresses appear in booking flow for quick selection

**Database Check:**
```sql
SELECT * FROM saved_addresses WHERE user_id = 'YOUR_USER_ID';
```

---

### 🗺️ **5. RECENT DESTINATIONS** (Priority: MEDIUM)

**Test Scenario:**
1. Complete 2-3 rides to different destinations
2. Navigate to destination picker in booking flow
3. Check if recent destinations appear

**Expected Result:**
- ✅ Recent destinations auto-tracked after ride completion
- ✅ Visit count increments for repeated destinations
- ✅ Sorted by most recent or most frequent
- ✅ Last visited time displayed

**Database Check:**
```sql
SELECT * FROM recent_destinations
WHERE user_id = 'YOUR_USER_ID'
ORDER BY last_visited_at DESC;
```

**Manual Upsert Test:**
```sql
-- Test the upsert function
SELECT upsert_recent_destination(
    'YOUR_USER_ID'::UUID,
    'Test Destination Address',
    -4.3276,
    15.3136
);

-- Run again to test visit count increment
SELECT upsert_recent_destination(
    'YOUR_USER_ID'::UUID,
    'Test Destination Address',
    -4.3276,
    15.3136
);

-- Verify visit_count = 2
SELECT * FROM recent_destinations
WHERE address = 'Test Destination Address';
```

---

### 💰 **6. DRIVER MOBILE MONEY SETUP** (Priority: CRITICAL)

**Test Scenario:**
1. Login as driver
2. Navigate to Mobile Money Setup page
3. Add M-Pesa account:
   - Provider: M-Pesa
   - Phone: +243XXXXXXXXX
   - Account Name: [Driver's name]
   - Set as Primary
4. Add Orange Money account (not primary)
5. Try setting Orange as primary

**Expected Result:**
- ✅ M-Pesa account created
- ✅ Orange Money account created
- ✅ When Orange set to primary, M-Pesa automatically becomes non-primary
- ✅ Only ONE primary account at a time
- ✅ Account visible to customers for payment

**Database Check:**
```sql
SELECT * FROM driver_mobile_money
WHERE driver_id = 'YOUR_DRIVER_ID'
ORDER BY is_primary DESC;

-- Should see only ONE is_primary = true
```

---

### 💸 **7. TRIP PAYMENT FLOW** (Priority: CRITICAL)

**Test Scenario:**
1. **Driver:** Set up M-Pesa as primary account (+243700123456)
2. **Customer:** Complete a ride (Amount: 5000 CDF)
3. **Customer:** Navigate to Trip Payment page
4. **Customer:** See 3 steps:
   - Step 1: Payment details (Amount: 5000 CDF, Commission: 500 CDF)
   - Step 2: USSD Instructions for M-Pesa
   - Step 3: Confirmation
5. **Customer:** Manually dial USSD on phone:
   ```
   *555#
   Send Money
   Enter: 0700123456
   Amount: 5000
   PIN: [Your PIN]
   ```
6. **Customer:** Enter M-Pesa transaction code (e.g., "QH8X2J5K")
7. **Customer:** Confirm payment in app
8. **Driver:** Receive notification
9. **Driver:** Confirm receipt

**Expected Result:**
- ✅ Payment record created with status = 'pending'
- ✅ Customer sees USSD instructions with driver's number
- ✅ Customer can copy driver's number
- ✅ After customer confirms: status = 'customer_confirmed'
- ✅ After driver confirms: status = 'completed'
- ✅ Commission auto-deducted from driver wallet
- ✅ Transaction reference saved

**Database Check:**
```sql
SELECT
    id,
    trip_id,
    amount,
    commission_amount,
    driver_net_amount,
    payment_method,
    customer_confirmed,
    driver_confirmed,
    status,
    transaction_reference
FROM trip_payments
WHERE trip_id = 'YOUR_TRIP_ID';
```

**USSD Instructions Display:**
```
M-Pesa Payment Instructions:

1. Dial *555# on your phone
2. Select "Send Money"
3. Enter number: 0700123456
4. Enter amount: 5000
5. Enter your PIN
6. Enter Driver ID as reference

After payment, enter the M-Pesa transaction code below.
```

---

### 💳 **8. DRIVER COMMISSION PAYMENT** (Priority: HIGH)

**Test Scenario:**
1. **Admin:** Manually set driver wallet balance to negative (e.g., -10000 CDF)
2. **Driver:** Navigate to Wallet Commission page
3. **Driver:** View outstanding commission (10000 CDF)
4. **Driver:** Submit payment:
   - Amount: 10000
   - Method: M-Pesa
   - Transaction Reference: "QH8X2J5K"
   - Upload receipt (screenshot)
5. **Driver:** View payment status = 'pending'
6. **Admin:** Verify payment (future feature)

**Expected Result:**
- ✅ Wallet summary displays negative balance as outstanding commission
- ✅ Driver can submit payment with proof
- ✅ Receipt uploaded to Supabase storage
- ✅ Payment status tracked (pending → verified → wallet updated)

**Database Check:**
```sql
SELECT * FROM wallet_commission_payments
WHERE driver_id = 'YOUR_DRIVER_ID'
ORDER BY created_at DESC;
```

**Storage Check:**
- Navigate to Supabase Storage → `documents/commission_proofs/`
- Verify image uploaded

---

### 📍 **9. LIVE LOCATION SHARING** (Priority: MEDIUM)

**Test Scenario:**
1. Start an active trip
2. Click "Share Location" button
3. Choose WhatsApp or SMS
4. Send to emergency contact or friend
5. Recipient opens link

**Expected Result:**
- ✅ Google Maps link generated with current lat/lng
- ✅ Link opens in Google Maps app or browser
- ✅ Real-time location updates (if implemented)
- ✅ System share dialog appears

**Link Format:**
```
https://www.google.com/maps?q=-4.3276,15.3136
```

---

## 🔍 CRITICAL SECURITY TESTS

### Test 1: Row Level Security
**Customer A tries to access Customer B's data:**
```dart
// Should return empty or throw error
final result = await supabase
    .from('saved_addresses')
    .select()
    .eq('user_id', 'CUSTOMER_B_ID'); // Different user

// Expected: Empty or error (RLS blocks access)
```

### Test 2: Driver Can't See Other Driver's Mobile Money
```dart
// Driver A logged in
final result = await supabase
    .from('driver_mobile_money')
    .select()
    .eq('driver_id', 'DRIVER_B_ID');

// Expected: Empty (RLS blocks)
```

### Test 3: Emergency Contact Limit
```dart
// Try adding 4th contact
// Expected: UNIQUE constraint violation on priority_order
```

### Test 4: Single Primary Mobile Money
```dart
// Driver has M-Pesa as primary
// Add Orange Money and set to primary
// Expected: M-Pesa automatically becomes non-primary
```

---

## 📊 PERFORMANCE TESTS

### Test 1: Nearby Driver Search (SOS)
```sql
-- Find drivers within 5km of Kinshasa center
EXPLAIN ANALYZE
SELECT * FROM profiles p
JOIN driver_location dl ON p.id = dl.driver_id
WHERE earth_distance(
  ll_to_earth(dl.latitude, dl.longitude),
  ll_to_earth(-4.3276, 15.3136)
) < 5000;

-- Expected: Uses spatial index, < 100ms
```

### Test 2: Recent Destinations Query
```sql
EXPLAIN ANALYZE
SELECT * FROM recent_destinations
WHERE user_id = 'YOUR_USER_ID'
ORDER BY last_visited_at DESC
LIMIT 10;

-- Expected: Uses index, < 50ms
```

---

## 🚀 PRE-LAUNCH CHECKLIST

- [ ] All 7 tables created in Supabase
- [ ] RLS enabled on all tables
- [ ] Storage bucket `documents` created
- [ ] SMS permissions granted on Android
- [ ] At least 3 emergency contacts added for test user
- [ ] Passenger SOS sends SMS to contacts
- [ ] Driver SOS notifies nearby drivers
- [ ] Mobile money accounts can be added/edited
- [ ] Trip payment flow works end-to-end
- [ ] Commission payment can be submitted
- [ ] Saved addresses persist across sessions
- [ ] Recent destinations auto-track
- [ ] Live location sharing works
- [ ] No compilation errors
- [ ] Build succeeds on Android
- [ ] App runs on physical device

---

## 🇨🇩 CONGO MARKET SPECIFICS

### Mobile Money Providers to Test:
1. **Vodacom M-Pesa**: Most popular in DRC
2. **Orange Money**: Second most popular
3. **Airtel Money**: Growing market share

### Phone Number Format:
- International: +243 XXX XXX XXX
- Local: 0XXX XXX XXX

### Test Locations (Kinshasa):
- Gombe: -4.3097, 15.3058
- Limete: -4.3862, 15.3456
- Kintambo: -4.3276, 15.2894

### Average Ride Costs for Testing:
- Short trip (2-5km): 2000-5000 CDF
- Medium trip (5-10km): 5000-10000 CDF
- Long trip (10km+): 10000-20000 CDF

### Commission Rates:
- Standard: 10% (500 CDF on 5000 CDF ride)

---

## 📞 EMERGENCY CONTACTS

Test with real phone numbers (your own or colleagues) to verify SMS delivery:
- Format: +243 XXX XXX XXX
- Vodacom: +243 81/82/83/84/85/89/90/91/92/93/94/97/98/99
- Airtel: +243 97/98
- Orange: +243 80/81/82/83/84/85/86/87/88

---

## 🎉 SUCCESS CRITERIA

Your app is ready for Congo launch when:
- ✅ All database tables accessible
- ✅ SOS alerts work reliably
- ✅ Mobile money payment instructions clear
- ✅ No crashes during normal usage
- ✅ Location tracking accurate
- ✅ Emergency contacts notified within 5 seconds
- ✅ Drivers receive SOS within 10 seconds
- ✅ Payment confirmations work
- ✅ Data persists across sessions

---

**🇨🇩 ALBOCARRIDE - READY FOR CONGO!** 🚀
