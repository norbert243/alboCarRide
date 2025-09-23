# 🧪 Driver-Side QA Testing Script

## 📋 Test Setup Requirements

### Test Accounts Needed
- **Driver Account**: Phone number for driver testing
- **Rider Account**: Phone number for rider testing
- **Test Devices**: At least 2 real devices (preferably one low-end Android for Congo conditions)
- **Network Simulation**: 3G mode for weak network testing

### Database Monitoring
- Keep Supabase dashboard open to monitor real-time changes
- Watch `auth.users`, `profiles`, `driver_documents`, `ride_offers`, `trips`, `driver_locations`, `notifications` tables

---

## 🔐 1. Authentication & Session Testing

### Test 1.1 – New Driver Registration
**Action:**
1. Open app fresh installation
2. Enter driver phone number
3. Receive and enter OTP
4. Complete registration

**Expected Results:**
- ✅ OTP verification succeeds via Twilio
- ✅ Driver redirected to Verification Page (since unverified)
- ✅ DB: New row in `auth.users` with driver phone
- ✅ DB: New row in `profiles` with `role = 'driver'` and `verified = false`

### Test 1.2 – Session Persistence
**Action:**
1. Complete Test 1.1 successfully
2. Close app completely
3. Wait 5 minutes
4. Reopen app

**Expected Results:**
- ✅ Session persists - no login required
- ✅ Driver lands on Verification Page (still unverified)
- ✅ No data loss or corruption

### Test 1.3 – Duplicate Registration Prevention
**Action:**
1. Try to register with same phone number used in Test 1.1
2. Attempt OTP verification

**Expected Results:**
- ✅ Registration fails with "Phone number already registered" message
- ✅ No duplicate rows in `auth.users` or `profiles`

---

## 📄 2. Driver Verification Testing

### Test 2.1 – Document Upload (Car Driver)
**Action:**
1. On Verification Page, select "Car" as vehicle type
2. Upload driver's license photo
3. Upload ID photo
4. Submit verification

**Expected Results:**
- ✅ Files compress successfully (check file sizes < 500KB)
- ✅ Upload completes even on simulated 3G network
- ✅ DB: New rows in `driver_documents` with `status = 'pending'`
- ✅ UI shows "Verification Pending" status

### Test 2.2 – Document Upload (Moto Driver)
**Action:**
1. Use different test account, select "Motorcycle" as vehicle type
2. Upload motorcycle license + ID
3. Submit verification

**Expected Results:**
- ✅ Same success criteria as Test 2.1
- ✅ Vehicle type correctly stored in database

### Test 2.3 – Verification Status Update
**Action:**
1. Complete Test 2.1
2. In Supabase dashboard: Update `profiles.verified = true` for test driver
3. Refresh app or navigate

**Expected Results:**
- ✅ App automatically detects status change
- ✅ Redirects to Enhanced Driver Home Page
- ✅ Online/Offline toggle becomes available

### Test 2.4 – Verification Rejection
**Action:**
1. Complete Test 2.1 with another test account
2. In Supabase: Update `profiles.verified = false` (rejection)
3. Refresh app

**Expected Results:**
- ✅ App shows rejection message
- ✅ Driver stays on Verification Page with option to re-upload
- ✅ Clear instructions for correction

---

## 💰 3. Offer & Negotiation Testing

### Test 3.1 – Receive Real-time Offer
**Prerequisite:** Driver verified and online

**Action:**
1. Rider sends ride request through rider app
2. Monitor driver app in real-time

**Expected Results:**
- ✅ Offer appears instantly in Offer Board
- ✅ DB: New row in `ride_offers` with `status = 'pending'`
- ✅ Offer shows rider details, pickup/dropoff, proposed fare
- ✅ 10-minute countdown timer visible

### Test 3.2 – Accept Offer
**Action:**
1. Driver taps "Accept" on received offer
2. Monitor database changes

**Expected Results:**
- ✅ DB: `ride_offers.status = 'accepted'`
- ✅ DB: New row in `trips` with `status = 'scheduled'`
- ✅ App automatically switches from Offer Board to Trip Card
- ✅ Rider receives acceptance notification

### Test 3.3 – Reject Offer
**Action:**
1. Driver receives new offer
2. Tap "Reject"
3. Confirm rejection

**Expected Results:**
- ✅ DB: `ride_offers.status = 'rejected'`
- ✅ Offer disappears from Offer Board
- ✅ Rider receives rejection notification
- ✅ Driver remains online for new offers

### Test 3.4 – Counter Offer (Valid Range)
**Action:**
1. Driver receives offer with fare = 1000
2. Tap "Counter Offer"
3. Enter 1300 (within +30%)
4. Submit counter

**Expected Results:**
- ✅ DB: `ride_offers.counter_amount = 1300`
- ✅ Rider sees counter offer
- ✅ Counter offer has its own 10-minute timer

### Test 3.5 – Counter Offer (Invalid Range)
**Action:**
1. Driver receives offer with fare = 1000
2. Attempt to counter with 2000 (outside +50% range)

**Expected Results:**
- ✅ App shows error: "Counter offer must be within ±30-50% of original fare"
- ✅ Counter not submitted to database
- ✅ Driver can adjust amount and retry

### Test 3.6 – Offer Expiry
**Action:**
1. Driver receives offer
2. Do nothing for 10 minutes
3. Monitor automatic expiry

**Expected Results:**
- ✅ After 10 minutes: DB: `ride_offers.status = 'expired'`
- ✅ Offer disappears from Offer Board
- ✅ Rider receives expiry notification

---

## 🚗 4. Trip Lifecycle Testing

### Test 4.1 – Start Trip
**Prerequisite:** Trip in 'scheduled' status

**Action:**
1. Driver on Trip Card screen
2. Tap "Start Trip" button
3. Confirm action

**Expected Results:**
- ✅ DB: `trips.status = 'in_progress'`
- ✅ DB: `trips.start_time` populated with current timestamp
- ✅ Trip Card shows "In Progress" status
- ✅ Rider receives "Trip Started" notification
- ✅ Location tracking continues

### Test 4.2 – Complete Trip
**Action:**
1. Trip in 'in_progress' status
2. Driver arrives at destination
3. Tap "Complete Trip"

**Expected Results:**
- ✅ DB: `trips.status = 'completed'`
- ✅ DB: `trips.end_time` populated
- ✅ Trip Card shows completion summary
- ✅ Driver automatically returns to Offer Board (if online)
- ✅ Rider receives "Trip Completed" notification
- ✅ Earnings calculated and stored

### Test 4.3 – Cancel Trip (With Reason)
**Action:**
1. Trip in 'scheduled' or 'in_progress' status
2. Driver taps "Cancel Trip"
3. Select cancellation reason from dialog
4. Confirm cancellation

**Expected Results:**
- ✅ DB: `trips.status = 'cancelled'`
- ✅ DB: `trips.cancel_reason` stores selected reason
- ✅ Trip Card shows cancellation message
- ✅ Driver returns to Offer Board
- ✅ Rider receives cancellation notification with reason

### Test 4.4 – Cancel Trip (No Reason)
**Action:**
1. Attempt to cancel without selecting reason
2. Try to proceed

**Expected Results:**
- ✅ App prevents cancellation until reason selected
- ✅ Error message: "Please select a cancellation reason"
- ✅ Cancellation only proceeds after reason provided

---

## 📍 5. Location Services Testing

### Test 5.1 – Online Location Tracking
**Action:**
1. Verified driver goes online
2. Monitor for 2 minutes
3. Check database updates

**Expected Results:**
- ✅ Location updates every 30 seconds (watch console logs)
- ✅ DB: `driver_locations` receives new coordinates
- ✅ DB: `drivers.current_latitude/longitude` updated
- ✅ No excessive battery drain

### Test 5.2 – Offline Status
**Action:**
1. Driver goes offline using toggle
2. Monitor for 1 minute

**Expected Results:**
- ✅ Location updates stop immediately
- ✅ DB: No new location records
- ✅ Driver shows as offline in system

### Test 5.3 – Weak Network Simulation
**Action:**
1. Enable airplane mode or throttle network to 3G
2. Driver goes online
3. Attempt location updates

**Expected Results:**
- ✅ App shows "Offline" badge
- ✅ Location updates queue and sync when network returns
- ✅ No app crashes or data loss
- ✅ Graceful reconnection when network restored

### Test 5.4 – Background Location (Basic)
**Action:**
1. Driver goes online
2. Minimize app
3. Wait 1 minute
4. Reopen app

**Expected Results:**
- ✅ Location tracking continues (basic simulation)
- ✅ Trip status preserved
- ✅ No session issues on resume

---

## 🔔 6. Notifications Testing

### Test 6.1 – Offer Acceptance Notification
**Action:**
1. Rider accepts driver's counter-offer
2. Monitor driver app

**Expected Results:**
- ✅ Driver receives instant in-app notification
- ✅ Notification shows "Rider accepted your counter-offer"
- ✅ DB: New row in `notifications` table

### Test 6.2 – Trip Start Notification
**Action:**
1. Driver starts trip
2. Monitor rider app

**Expected Results:**
- ✅ Rider receives "Driver has started your trip" notification
- ✅ Notification includes driver ETA if available

### Test 6.3 – Trip Completion Notification
**Action:**
1. Driver completes trip
2. Monitor both apps

**Expected Results:**
- ✅ Both driver and rider receive completion notifications
- ✅ Driver notification includes earnings summary
- ✅ Rider notification includes fare and rating prompt

### Test 6.4 – Notification Mark as Read
**Action:**
1. Driver receives notification
2. Tap on notification

**Expected Results:**
- ✅ Notification marked as read in UI
- ✅ DB: `notifications.is_read = true`
- ✅ Notification disappears from unread count

### Test 6.5 – Batch Notifications
**Action:**
1. Driver receives multiple notifications rapidly
2. Test notification handling

**Expected Results:**
- ✅ All notifications delivered without loss
- ✅ Notifications stack properly
- ✅ Marking one as read doesn't affect others

---

## 🏠 7. Driver Home Page UX Testing

### Test 7.1 – Verified Driver Entry
**Action:**
1. Verified driver logs in
2. Observe landing page

**Expected Results:**
- ✅ Lands directly on Enhanced Driver Home Page
- ✅ Online/Offline toggle visible and functional
- ✅ Correct initial state (offline by default)

### Test 7.2 – Online/Offline Toggle
**Action:**
1. Tap Online toggle
2. Wait for location updates
3. Tap Offline toggle

**Expected Results:**
- ✅ Toggle state syncs with DB: `drivers.is_online`
- ✅ Location service starts/stops accordingly
- ✅ UI reflects current online status clearly

### Test 7.3 – Conditional Rendering (No Active Trip)
**Action:**
1. Driver online with no active trips
2. Observe screen

**Expected Results:**
- ✅ Offer Board visible with "Waiting for offers" message
- ✅ Trip Card hidden
- ✅ Location tracking active

### Test 7.4 – Conditional Rendering (Active Trip)
**Action:**
1. Driver accepts offer (from Test 3.2)
2. Observe screen transition

**Expected Results:**
- ✅ Offer Board automatically hides
- ✅ Trip Card appears with trip details
- ✅ Navigation restricted to trip management only

### Test 7.5 – Sign Out Functionality
**Action:**
1. Driver taps Sign Out
2. Confirm logout
3. Attempt to reopen app

**Expected Results:**
- ✅ Session cleared completely
- ✅ Location tracking stops
- ✅ Redirected to login screen
- ✅ No residual data or state issues

### Test 7.6 – App State Recovery
**Action:**
1. Driver in middle of trip
2. Force close app
3. Reopen app

**Expected Results:**
- ✅ App recovers to correct state (Trip Card visible)
- ✅ Trip status preserved
- ✅ Location tracking resumes
- ✅ No data corruption

---

## 🚨 Edge Cases & Error Handling

### Test 8.1 – Network Failure During Critical Operation
**Action:**
1. Start trip acceptance process
2. Cut network mid-operation
3. Restore network

**Expected Results:**
- ✅ Operation fails gracefully with error message
- ✅ No partial database updates
- ✅ Retry mechanism available
- ✅ State consistency maintained

### Test 8.2 – Concurrent Offer Handling
**Action:**
1. Send multiple offers to driver simultaneously
2. Test acceptance/rejection handling

**Expected Results:**
- ✅ Only one offer can be accepted at a time
- ✅ Other offers automatically expire or reject
- ✅ Clear feedback for driver about offer conflicts

### Test 8.3 – Database Connection Issues
**Action:**
1. Simulate Supabase downtime
2. Attempt various operations

**Expected Results:**
- ✅ App shows appropriate offline messages
- ✅ Operations queue for retry
- ✅ No app crashes or data loss

---

## 📊 Test Results Tracking

| Test Category | Test ID | Status | Notes | Tester | Date |
|---------------|---------|--------|-------|--------|------|
| Authentication | 1.1 | □ | | | |
| Authentication | 1.2 | □ | | | |
| Authentication | 1.3 | □ | | | |
| Verification | 2.1 | □ | | | |
| Verification | 2.2 | □ | | | |
| Verification | 2.3 | □ | | | |
| Verification | 2.4 | □ | | | |
| Offers | 3.1 | □ | | | |
| Offers | 3.2 | □ | | | |
| Offers | 3.3 | □ | | | |
| Offers | 3.4 | □ | | | |
| Offers | 3.5 | □ | | | |
| Offers | 3.6 | □ | | | |
| Trips | 4.1 | □ | | | |
| Trips | 4.2 | □ | | | |
| Trips | 4.3 | □ | | | |
| Trips | 4.4 | □ | | | |
| Location | 5.1 | □ | | | |
| Location | 5.2 | □ | | | |
| Location | 5.3 | □ | | | |
| Location | 5.4 | □ | | | |
| Notifications | 6.1 | □ | | | |
| Notifications | 6.2 | □ | | | |
| Notifications | 6.3 | □ | | | |
| Notifications | 6.4 | □ | | | |
| Notifications | 6.5 | □ | | | |
| UX | 7.1 | □ | | | |
| UX | 7.2 | □ | | | |
| UX | 7.3 | □ | | | |
| UX | 7.4 | □ | | | |
| UX | 7.5 | □ | | | |
| UX | 7.6 | □ | | | |
| Edge Cases | 8.1 | □ | | | |
| Edge Cases | 8.2 | □ | | | |
| Edge Cases | 8.3 | □ | | | |

## 🎯 Testing Completion Criteria

**PASS**: All critical path tests (1.1, 2.1, 3.1, 3.2, 4.1, 4.2, 5.1, 7.1) must pass
**READY FOR DEPLOYMENT**: ≥90% of all tests pass with no critical failures
**RETEST REQUIRED**: Any critical path failure requires full regression testing

---
*Last Updated: 2025-09-22*
*Test Script Version: 1.0*