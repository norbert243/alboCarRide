# Formspree Contact Form - Quick Start Guide

## 5-Minute Setup

### 1. Get Your Formspree Form ID (2 minutes)
1. Go to https://formspree.io/ and sign up
2. Click "+ New Form"
3. Name it "AlboCarRide Support"
4. Copy your form endpoint URL: `https://formspree.io/f/xyzabc123`

### 2. Update the Code (1 minute)
1. Open: `lib/screens/home/support_page.dart`
2. Find line 29: `static const String _formspreeEndpoint = ...`
3. Replace `YOUR_FORM_ID` with your actual ID
4. Save the file

### 3. Test (2 minutes)
```bash
flutter pub get
flutter run
```

Navigate to Support page → Fill form → Submit → Check Formspree dashboard

## That's It!

The contact form is now live and will send all submissions to your email.

## Key Features
✅ Auto-fills user name and email
✅ 9 issue type categories
✅ Robust error handling
✅ Retry on failure
✅ Works even if app crashes
✅ Email notifications
✅ Mobile-optimized UI

## Next Steps
- Configure email notifications in Formspree dashboard
- Add your support email address
- Enable auto-responder (optional)
- Test with real data

## Need Help?
See detailed guide: `FORMSPREE_CONTACT_SETUP.md`

## Form Fields
- **Name** (required, min 2 chars)
- **Email** (required, valid format)
- **Issue Type** (dropdown, required)
- **Message** (required, 20-1000 chars)

## Contact Info Included
Each submission automatically includes:
- User ID
- Phone number
- Timestamp
- Platform: "mobile_app"

---
**Ready to go in 5 minutes! 🚀**
