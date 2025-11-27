# SOS System Quick Start Guide

## 🚀 For Developers

### How to Test Passenger SOS Locally

1. **Add Emergency Contacts:**
   ```
   Navigate to: Account Tab → Safety → Emergency contacts
   Add 3 contacts with your test phone numbers
   ```

2. **Start a Trip:**
   ```
   Book a ride → Wait for driver to accept → Driver starts trip
   Trip status must be "in_progress"
   ```

3. **Trigger SOS:**
   ```
   On RiderTripTrackingPage → Hold red SOS button for 3 seconds
   Watch circular progress indicator fill up
   Release after 3 seconds → SOS triggers
   ```

4. **Expected Behavior:**
   ```
   ✅ SMS app opens with pre-filled message for each contact (if SMS enabled)
   ✅ WhatsApp opens with pre-filled message for each contact (if WhatsApp enabled)
   ✅ Confirmation dialog appears
   ✅ Incident created in database
   ```

### How to Test Driver SOS Locally

1. **Switch to Driver Account**

2. **Start an Active Trip**

3. **Trigger SOS:**
   ```
   Hold SOS button for 3 seconds
   ```

4. **Expected Behavior:**
   ```
   ✅ API call to /api/v1/driver/sos
   ✅ Nearby drivers queried from database
   ✅ Notifications created in database
   ✅ Admin alert logged
   ```

## 🔧 Key Files to Know

| File | Purpose |
|------|---------|
| `lib/services/emergency_sos_service.dart` | Core SOS logic |
| `lib/widgets/sos_button.dart` | SOS button UI & interaction |
| `lib/screens/home/safety_page.dart` | Safety hub UI |
| `lib/screens/emergency/emergency_contacts_page.dart` | Contacts management |
| `lib/screens/home/rider_trip_tracking_page.dart` | SOS button placement |

## 🐛 Debugging Tips

### SOS Button Not Showing
- Check trip status: Must be `"in_progress"`
- Check `_currentTrip` is not null
- Look for floating action button in widget tree

### SMS/WhatsApp Not Opening
- Check `url_launcher` package is installed
- Verify phone number format (+243...)
- Test on physical device (not emulator)

### Location Not Fetching
- Check location permissions granted
- Check GPS is enabled
- Use physical device (emulator GPS is unreliable)

### API Errors
- Check authentication token is valid
- Verify backend endpoint is running
- Check network connectivity
- Review API response in logs

## 📱 Testing on Physical Device

### Android Debug Build
```bash
flutter run --debug
```

### Test Checklist
- [ ] Hold SOS button for 3 seconds
- [ ] Verify circular progress animation
- [ ] Check SMS app opens
- [ ] Check WhatsApp opens
- [ ] Verify Google Maps link in message
- [ ] Check confirmation dialog
- [ ] Test with 0 contacts (should error)
- [ ] Test with 1, 2, 3 contacts
- [ ] Test during non-active trip (button hidden)

## 🌍 DRC Testing Notes

### Network Conditions
- Test on 2G/3G/4G
- Test with poor signal
- Test in airplane mode (should show error)

### Carrier Testing
- Test SMS on Vodacom DRC
- Test SMS on Airtel DRC
- Test SMS on Orange DRC
- Verify international format: +243...

### Phone Number Formats
```
Correct: +243900000000
Correct: +243800000000
Incorrect: 0900000000 (missing country code)
```

## 🔐 Security Testing

### Authentication
- Test without login (should fail)
- Test with expired token (should fail)
- Test with different user's token (should fail)

### Rate Limiting
- Try 4+ SOS in 1 hour (should block on backend)

### Data Validation
- Test with invalid coordinates
- Test with missing required fields
- Test with SQL injection attempts

## 📊 Monitoring

### What to Monitor
- SOS trigger frequency
- API response times
- FCM delivery success rate
- False alarm rate
- GPS accuracy

### Logs to Check
```dart
// In emergency_sos_service.dart
print('Error triggering SOS: $e');
print('Failed to send WhatsApp message: $e');
print('Failed to send SMS: $e');
print('Failed to get nearby drivers: $e');
```

## ⚡ Performance Tips

### Optimize Location Fetching
- Use `LocationAccuracy.high` for SOS only
- Cache last known location
- Timeout after 10 seconds

### Optimize Database Queries
- Use indexes on `user_id`, `status`
- Limit results to active drivers only
- Filter by distance efficiently

## 📞 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "No emergency contacts" error | Add contacts in Safety page |
| Location permission denied | Request in app settings |
| SMS not sending | Check phone number format |
| WhatsApp not installed | Fallback to SMS only |
| API timeout | Check network, increase timeout |
| SOS button not holding | Check animation controller |

## 🎯 Quick Commands

### Run Tests
```bash
flutter test test/services/emergency_sos_service_test.dart
```

### Check Logs
```bash
flutter logs | grep "SOS"
```

### Build Release
```bash
flutter build apk --release
```

## 📋 Pre-Launch Checklist

- [ ] All emergency contacts use +243 format
- [ ] Test on 3+ different Android devices
- [ ] Test on Vodacom, Airtel, Orange networks
- [ ] Verify SMS delivery (actual send, not just app open)
- [ ] Verify WhatsApp delivery
- [ ] Test GPS accuracy in urban Kinshasa
- [ ] Test in low battery mode
- [ ] Test in background/foreground
- [ ] Review all error messages (French translation)
- [ ] Load test with 100+ requests

## 🆘 Emergency Contacts

**Dev Team Lead:** [PHONE]
**Backend Team:** [PHONE]
**QA Team:** [PHONE]
**On-Call Support:** [PHONE]

---

**Last Updated:** 2025-11-18
**Version:** 1.0
