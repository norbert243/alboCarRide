# 📱 Contact/Support Form - Visual Guide

## Form Layout

```
┌─────────────────────────────────────┐
│         Support Page                │
├─────────────────────────────────────┤
│                                     │
│  Quick Contact                      │
│  ┌─────────────────────────────┐   │
│  │ 📞 Call Support             │   │
│  │ Speak directly with our team│   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📧 Email Support            │   │
│  │ Send us an email            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 💬 Live Chat                │   │
│  │ Chat with support agent     │   │
│  └─────────────────────────────┘   │
│                                     │
│  Submit Support Request             │
│  ┌─────────────────────────────┐   │
│  │ 👤 Your Name                │   │
│  │ [John Doe]                  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✉️ Email Address             │   │
│  │ [john@example.com]          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📂 Issue Type               │   │
│  │ [General Inquiry ▼]         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 💬 Message / Description     │   │
│  │                             │   │
│  │ [Type your message here...] │   │
│  │                             │   │
│  │                             │   │
│  │                    125/1000 │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📨 Submit Support Request  │   │
│  └─────────────────────────────┘   │
│                                     │
│  We typically respond within        │
│  24 hours                           │
│                                     │
│  Frequently Asked Questions         │
│  ▼ How do I book a ride?            │
│  ▼ How is the fare calculated?      │
│  ▼ What payment methods accepted?   │
│  ▼ How do I cancel a ride?          │
│  ▼ What if I have driver issues?    │
│                                     │
│  ⚠️ Emergency Contact               │
│  For emergencies, contact local     │
│  authorities immediately            │
│                                     │
└─────────────────────────────────────┘
```

## Issue Type Dropdown Options

```
┌───────────────────────────────┐
│ Select Issue Type             │
├───────────────────────────────┤
│ • General Inquiry             │
│ • App Crash/Technical Issue   │
│ • Booking Problem             │
│ • Payment Issue               │
│ • Driver Issue                │
│ • Account Problem             │
│ • Feature Request             │
│ • Safety Concern              │
│ • Other                       │
└───────────────────────────────┘
```

## Form States

### 1. Initial State
```
┌─────────────────────────────┐
│ 📨 Submit Support Request   │  ← Blue/Purple button
└─────────────────────────────┘
```

### 2. Loading State
```
┌─────────────────────────────┐
│    ⏳ [Spinner]              │  ← Disabled, gray button
└─────────────────────────────┘
```

### 3. Success State
```
┌───────────────────────────────────────┐
│ ✅ Support request submitted          │  ← Green snackbar
│    successfully! We'll get back to    │
│    you soon.                          │
└───────────────────────────────────────┘
```

### 4. Error State
```
┌─────────────────────────────────────┐
│ ⚠️ Network Error                     │  ← Error dialog
│                                     │
│ Unable to connect to the server.    │
│ Please check your internet          │
│ connection and try again.           │
│                                     │
│        [Retry]        [OK]          │
└─────────────────────────────────────┘
```

## Validation Examples

### Valid Form
```
Name:       John Doe ✅
Email:      john@example.com ✅
Issue:      App Crash/Technical Issue ✅
Message:    The app crashes when I try to book
            a ride from the airport. It happens
            every time. ✅ (60 characters)
```

### Invalid Form Examples

#### Too Short Name
```
Name:       J ❌
Error:      "Name must be at least 2 characters"
```

#### Invalid Email
```
Email:      john@invalid ❌
Error:      "Please enter a valid email address"
```

#### Message Too Short
```
Message:    App crashes ❌ (12 characters)
Error:      "Please provide more details (at least 20 characters)"
```

## Data Flow Diagram

```
┌──────────┐
│   User   │
└────┬─────┘
     │ Fills form
     ▼
┌──────────────────┐
│ Form Validation  │
└────┬─────────────┘
     │ Valid ✅
     ▼
┌──────────────────┐
│  Loading State   │  ← Button shows spinner
└────┬─────────────┘
     │
     ▼
┌──────────────────────────────────┐
│ HTTP POST to Formspree           │
│                                  │
│ Endpoint: formspree.io/f/{ID}    │
│ Method: POST                     │
│ Body: {                          │
│   name, email, issueType,        │
│   message, userId, phone,        │
│   timestamp, platform            │
│ }                                │
│ Timeout: 15 seconds              │
└────┬─────────────────────────────┘
     │
     ├─── Success (200/201) ──────┐
     │                            │
     │                            ▼
     │                   ┌─────────────────┐
     │                   │ Success Message │
     │                   │ Clear Form      │
     │                   │ Reset Fields    │
     │                   └─────────────────┘
     │
     └─── Failure ───────────────┐
                                 │
                                 ▼
                        ┌─────────────────┐
                        │  Error Dialog   │
                        │  [Retry] [OK]   │
                        └─────────────────┘
```

## Email Notification (Received by Support Team)

```
From: forms@formspree.io
To: support@albocarride.com
Subject: New submission from AlboCarRide Support

Name: John Doe
Email: john@example.com
Issue Type: App Crash/Technical Issue
Message: The app crashes when I try to book a ride from
         the airport. It happens every time I select the
         pickup location.

Additional Info:
- User ID: abc123-def456-789
- Phone: +1234567890
- Timestamp: 2025-10-27T12:34:56.789Z
- Platform: mobile_app

---
Powered by Formspree
```

## Color Scheme

```
Primary Color:    Deep Purple (#673AB7)
Success:          Green (#4CAF50)
Error:            Red (#F44336)
Warning:          Orange (#FF9800)
Background:       Light Gray (#F5F5F5)
Text:             Dark Gray (#212121)
Border:           Light Gray (#E0E0E0)
```

## Button States

```
Normal:    [Blue/Purple background, white text]
Hover:     [Darker shade]
Pressed:   [Even darker shade]
Loading:   [Gray background, spinner]
Disabled:  [Light gray, no interaction]
```

## Field Icons

```
Name:         👤 (person icon)
Email:        ✉️ (envelope icon)
Issue Type:   📂 (category icon)
Message:      💬 (message icon)
Submit:       📨 (send icon)
```

## Responsive Behavior

### Portrait Mode (Most common)
```
┌─────────────┐
│   Content   │
│   Scrolls   │
│   Vertically│
│      ↓      │
│      ↓      │
│      ↓      │
└─────────────┘
```

### Landscape Mode
```
┌────────────────────────────────────┐
│        Content still scrolls       │
│        Fields maintain width       │
└────────────────────────────────────┘
```

## Accessibility Features

```
✅ Clear labels for all fields
✅ Proper input types (email keyboard for email field)
✅ Error messages read by screen readers
✅ Sufficient touch target sizes (min 48x48dp)
✅ Color contrast meets WCAG AA standards
✅ Focus indicators visible
✅ Logical tab order
```

## Network States Handled

```
🌐 Online + Good Connection
   → Normal submission (1-2 seconds)

📶 Online + Slow Connection
   → Shows loading, waits up to 15 seconds

✈️ Offline / Airplane Mode
   → Error dialog: "Network Error"
   → Retry option available

🔄 Intermittent Connection
   → Automatic timeout + retry option

🚫 Blocked by Firewall
   → Error dialog with alternate contact options
```

## User Experience Timeline

```
0s    │ User taps Support in menu
      │
0.5s  │ Support page loads
      │ Name & email auto-filled
      │
5s    │ User selects issue type
      │
20s   │ User types message
      │
21s   │ User taps Submit button
      │ → Button shows spinner
      │ → Form fields disabled
      │
22.5s │ Request sent to Formspree
      │
23.5s │ Response received (200 OK)
      │ → Success message appears
      │ → Form clears
      │ → Button re-enabled
      │
27.5s │ Success message auto-dismisses
      │
      │ Total: ~27 seconds (ideal case)
```

## Error Recovery Paths

```
                    [User Submits Form]
                            │
                ┌───────────┴───────────┐
                │                       │
           [Success]              [Failure]
                │                       │
                │           ┌───────────┴──────────┐
                │           │                      │
                │      [Network Error]      [Server Error]
                │           │                      │
                │      [Retry Dialog]         [Error Dialog]
                │           │                      │
                │      [User Retries]         [User Contacts
                │           │                  via Phone/Email]
                │      [Success/Fail]              │
                │           │                      │
                └───────────┴──────────────────────┘
                            │
                    [Issue Resolved]
```

## Performance Metrics

```
Page Load:           < 1 second
Auto-fill Data:      < 0.5 seconds
Form Validation:     Instant (< 100ms)
API Request:         1-15 seconds
Success Feedback:    Instant (< 100ms)
Error Feedback:      Instant (< 100ms)
```

---

## Quick Reference

| Element | Description | Location |
|---------|-------------|----------|
| Form | Main contact form | Middle of page |
| Quick Contact | Phone/Email/Chat | Top of page |
| FAQ | Common questions | Bottom of page |
| Emergency | Emergency contacts | Very bottom |
| Submit Button | Send form | End of form |

---

*Visual guide created: October 27, 2025*
*For: AlboCarRide Mobile App*
*Platform: Flutter (iOS & Android)*
