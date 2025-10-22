# RooCode Audit Prompt: Albo Driver Application Full-Stack Functionality Test

## AUDIT SCOPE & EXECUTION PROTOCOL

**Application:** Albo Driver Application (InDrive-inspired)
**Versions:** V0 to V9
**Audit Type:** Systematic, Sequential, Exhaustive Full-Stack Testing
**Constraint:** DO NOT modify or remove any existing functional code

---

## 1. AUTHENTICATION FLOW AUDIT

### Test Sequence:
1. **App Launch & Initialization**
   - Launch application from cold start
   - Verify all services initialize correctly (Supabase, Firebase, Telemetry)
   - Check for any startup errors or crashes

2. **Login/Registration Navigation**
   - Navigate to authentication screen
   - Verify UI components render correctly (text fields, buttons, validation)
   - Test both login and registration paths

3. **Credential Input & Validation**
   - Input valid phone number/email
   - Test invalid format validation
   - Verify proper error messaging

4. **OTP Generation & Receipt**
   - Trigger OTP generation via Twilio service
   - Verify OTP is successfully generated and sent
   - Check telemetry logging for OTP events

5. **OTP Verification**
   - Input received OTP code
   - Verify successful authentication
   - Test incorrect OTP handling
   - Confirm secure token storage

6. **Post-Auth Redirection**
   - Verify redirection to appropriate dashboard based on user role
   - Check session persistence
   - Validate user data loading

**Expected Results:**
- Smooth transitions between screens
- Correct field validation and error handling
- Successful OTP generation/receipt/verification
- Secure token storage and session management
- Proper redirection to driver dashboard

---

## 2. DRIVER ONBOARDING & DOCUMENT VERIFICATION AUDIT

### Test Sequence:
1. **Profile/Documents Section Access**
   - Navigate to driver profile section
   - Verify document upload interface renders correctly

2. **Document Upload Process**
   - Test file picker functionality for various file types
   - Upload required documents (license, vehicle registration, insurance)
   - Verify upload progress indicators
   - Check file size and format validation

3. **Document Association & Submission**
   - Confirm documents are properly associated with driver profile
   - Submit documents for verification
   - Verify backend processing initiation

4. **Verification Status Tracking**
   - Monitor verification status updates
   - Test status change notifications
   - Verify UI reflects accurate states (pending, approved, rejected)

5. **Document Management**
   - Test document replacement functionality
   - Verify document deletion handling
   - Check for duplicate document prevention

**Expected Results:**
- File picker functions correctly across platforms
- Uploads succeed with proper error handling
- Documents correctly associated with driver profile
- Backend processing reflected in real-time status updates
- UI shows accurate verification states with appropriate messaging

---

## 3. DRIVER DASHBOARD / HOME PAGE AUDIT

### Test Sequence:
1. **Dashboard Initialization**
   - Load main dashboard post-login
   - Verify all UI components render correctly
   - Check for loading states and error handling

2. **Driver Status Management**
   - Test online/offline toggle functionality
   - Verify status changes propagate to backend
   - Check real-time status updates

3. **Key Metrics Display**
   - Verify earnings display with live data
   - Test ratings system functionality
   - Check trip count and history accuracy
   - Validate real-time data synchronization

4. **Map Integration (if present)**
   - Initialize map view without errors
   - Test location services integration
   - Verify map controls and interactions
   - Check for performance issues

5. **Navigation System**
   - Test all navigation elements to other app sections
   - Verify drawer/sidebar functionality
   - Check back button behavior and navigation stack

**Expected Results:**
- All UI components render correctly without visual glitches
- Driver status toggles work reliably with backend sync
- Key metrics display accurate, live data from realtime subscriptions
- Map view initializes and functions without errors
- Navigation elements are responsive and intuitive

---

## 4. REALTIME PUSH NOTIFICATION SYSTEM (V9 FOCUS) AUDIT

### Test Sequence:
1. **Push Infrastructure Verification**
   - Confirm FCM token registration on app startup
   - Verify token storage in Supabase `fcm_tokens` table
   - Test token refresh mechanisms

2. **Ride Request Simulation**
   - Simulate new ride request through backend
   - Monitor push notification creation in `push_notifications` table
   - Verify notification payload structure

3. **FCM Delivery Chain**
   - Track notification delivery from Supabase to FCM
   - Verify FCM acceptance and processing
   - Monitor delivery latency and reliability

4. **Device Notification Reception**
   - Verify notification appears on device
   - Test both foreground and background scenarios
   - Check notification content accuracy

5. **Delivery Receipt Logging (V9 Feature)**
   - Monitor `push_delivery_logs` table for 'delivered' status
   - Verify background handler execution for receipt recording
   - Test delivery receipt accuracy and timing

6. **Notification Interaction**
   - Test notification tap/acknowledgment
   - Verify deep linking to appropriate screens
   - Check notification dismissal handling

**Expected Results:**
- Reliable, low-latency delivery of ride requests
- Accurate logging of delivery status in `push_delivery_logs`
- Background handler executes correctly for receipt updates
- Notifications trigger appropriate app responses
- Delivery statistics are accurately recorded

---

## 5. BACKGROUND SERVICE & STATE PERSISTENCE AUDIT

### Test Sequence:
1. **Background Transition Testing**
   - Place app in background state
   - Verify services continue running appropriately
   - Test memory management and resource cleanup

2. **Push Notification in Background**
   - Receive push notification while app is backgrounded
   - Verify notification display and handling
   - Test background FCM handler execution

3. **Foreground Restoration**
   - Reopen app from background state
   - Verify state preservation and restoration
   - Check for data consistency

4. **Deep Linking Functionality**
   - Test notification deep linking to specific screens
   - Verify proper navigation stack restoration
   - Check for context preservation

5. **Crash & Recovery Testing**
   - Simulate app crashes during background operations
   - Verify graceful recovery and state restoration
   - Test data integrity after unexpected termination

**Expected Results:**
- App state is preserved correctly during background/foreground transitions
- Notifications deep-link to appropriate screens with proper context
- No crashes or data loss during state changes
- Background services handle interruptions gracefully

---

## 6. INTER-PAGE NAVIGATION & FLOW AUDIT

### Test Sequence:
1. **Dashboard Navigation**
   - Test all navigation paths from main dashboard
   - Verify loading states and transitions
   - Check for navigation stack integrity

2. **Trip History Section**
   - Navigate to trip history page
   - Verify trip data loading and display
   - Test pagination and filtering functionality
   - Check trip detail views

3. **Earnings & Payments**
   - Access earnings dashboard
   - Verify transaction history loading
   - Test payment statistics and summaries
   - Check wallet balance synchronization

4. **Profile & Settings**
   - Navigate to profile management
   - Test profile editing functionality
   - Verify settings persistence
   - Check account management features

5. **Navigation Integrity**
   - Test back button behavior across all screens
   - Verify navigation stack management
   - Check for memory leaks in navigation
   - Test screen rotation and orientation changes

**Expected Results:**
- All transitions are fluid without perceptible lag
- Navigation stack is managed correctly with proper back behavior
- No screens remain blank or stuck in loading states
- Data fetches complete successfully with proper error handling
- UI remains responsive during navigation

---

## 7. END-TO-END RIDE FLOW SIMULATION AUDIT

### Test Sequence:
1. **Ride Request Reception**
   - Simulate ride request push notification
   - Verify request details display
   - Test request acceptance/decline functionality

2. **Pickup Phase**
   - Navigate to pickup location
   - Verify map integration and routing
   - Test arrival confirmation
   - Check real-time location tracking

3. **Trip Initiation**
   - Start trip with passenger onboard
   - Verify trip state transition
   - Test ongoing trip tracking
   - Check passenger information display

4. **Destination & Completion**
   - Navigate to destination
   - Verify arrival confirmation
   - End trip successfully
   - Test trip completion workflow

5. **Payment Processing**
   - Verify fare calculation accuracy
   - Test payment processing flow
   - Check wallet balance updates
   - Validate transaction recording

6. **Post-Trip Flow**
   - Verify rating system functionality
   - Test feedback submission
   - Check trip history update
   - Validate earnings calculation

**Expected Results:**
- Each screen in the ride flow loads data correctly
- All action buttons trigger intended backend operations
- Trip state machine progresses accurately through all stages
- UI updates reflect real-time state changes
- Database records maintain data integrity throughout the flow

---

## AUDIT REPORTING FORMAT

For each test sequence, report using the following format:

### [Test Area]: [Specific Test]
**Status:** PASS / FAIL / NEEDS REVIEW
**Observations:**
- [Detailed observation 1]
- [Detailed observation 2]
- [Performance metrics if applicable]
- [Data integrity checks]
- [UI/UX smoothness assessment]

**Recommendations:** (Only if status is FAIL or NEEDS REVIEW)
- [Specific actionable recommendation]
- [Priority level: HIGH/MEDIUM/LOW]

---

## AUDIT CONSTRAINTS & RULES

1. **Non-Destructive Testing:** Do not modify or remove any existing functional code
2. **Scope Adherence:** Test only against current V0-V9 implementation
3. **Feature Set Compliance:** Adhere strictly to InDrive-inspired feature set
4. **Sequential Execution:** Follow the defined test sequence without deviation
5. **Comprehensive Coverage:** Ensure all functionality areas are thoroughly tested
6. **Performance Baseline:** Establish performance benchmarks for future comparisons
7. **Data Integrity:** Verify data consistency across all system components
8. **Security Compliance:** Ensure all security measures function as intended

---

## EXECUTION COMMAND

Execute this audit by systematically probing each functionality area in the specified sequence. Document findings for each test case with specific observations and maintain the integrity of the existing codebase throughout the testing process.