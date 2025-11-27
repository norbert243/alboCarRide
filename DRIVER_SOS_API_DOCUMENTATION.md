# Driver SOS API Endpoint Documentation

## Overview
This document provides the technical specification for the `/api/v1/driver/sos` endpoint, which implements the Peer-to-Peer Driver SOS system as specified in blueprint2 for AlboCarRide.

## Endpoint Details

### POST `/api/v1/driver/sos`

Triggers an emergency SOS alert that notifies nearby active drivers within a 3-5km radius.

#### Request

**Headers:**
```http
Authorization: Bearer {driver_jwt_token}
Content-Type: application/json
```

**Body:**
```json
{
  "driver_id": "uuid-of-driver-in-distress",
  "latitude": -4.0435,
  "longitude": 21.7587,
  "trip_id": "optional-uuid-of-current-trip",
  "incident_type": "emergency"
}
```

**Field Descriptions:**
- `driver_id` (required): UUID of the driver triggering the SOS
- `latitude` (required): Current GPS latitude (high accuracy)
- `longitude` (required): Current GPS longitude (high accuracy)
- `trip_id` (optional): UUID of the current trip if SOS triggered during a ride
- `incident_type` (optional): Type of incident (default: "emergency")

#### Response

**Success (200 OK):**
```json
{
  "success": true,
  "incident_id": "uuid-of-sos-incident",
  "message": "SOS alert sent to 12 nearby drivers",
  "notified_drivers_count": 12,
  "timestamp": "2025-11-18T10:30:00Z"
}
```

**Error (400 Bad Request):**
```json
{
  "success": false,
  "error": "Missing required field: latitude",
  "code": "VALIDATION_ERROR"
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": "Invalid or expired authentication token",
  "code": "UNAUTHORIZED"
}
```

**Error (500 Internal Server Error):**
```json
{
  "success": false,
  "error": "Failed to send SOS notifications",
  "code": "INTERNAL_ERROR"
}
```

## Backend Logic Flow

### Step 1: Authentication & Validation
```javascript
// Node.js/Express example
router.post('/api/v1/driver/sos', authenticateDriver, async (req, res) => {
  const { driver_id, latitude, longitude, trip_id, incident_type } = req.body;

  // Validate required fields
  if (!driver_id || !latitude || !longitude) {
    return res.status(400).json({
      success: false,
      error: 'Missing required fields',
      code: 'VALIDATION_ERROR'
    });
  }

  // Verify authenticated driver matches request
  if (req.driver.id !== driver_id) {
    return res.status(403).json({
      success: false,
      error: 'Unauthorized to trigger SOS for different driver',
      code: 'FORBIDDEN'
    });
  }

  // Continue to next step...
});
```

### Step 2: Create SOS Incident Record
```javascript
// Create incident in database
const incident = await db.sos_incidents.create({
  id: generateUUID(),
  user_id: driver_id,
  user_role: 'driver',
  trip_id: trip_id || null,
  latitude: latitude,
  longitude: longitude,
  incident_type: incident_type || 'emergency',
  status: 'active',
  created_at: new Date().toISOString()
});
```

### Step 3: Get Active Drivers
```javascript
// Query all active drivers
const allActiveDrivers = await db.profiles
  .select('id', 'current_latitude', 'current_longitude', 'fcm_token')
  .where({ role: 'driver', is_online: true })
  .whereNotNull('current_latitude')
  .whereNotNull('current_longitude')
  .whereNot('id', driver_id); // Exclude the SOS driver
```

### Step 4: Geofencing Filter (3-5km radius)
```javascript
// Haversine formula to calculate distance
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon/2) * Math.sin(dLon/2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c; // Distance in km
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

// Filter drivers within 5km radius
const RADIUS_KM = 5;
const nearbyDrivers = allActiveDrivers.filter(driver => {
  const distance = calculateDistance(
    latitude,
    longitude,
    driver.current_latitude,
    driver.current_longitude
  );
  return distance <= RADIUS_KM;
});
```

### Step 5: Send FCM Push Notifications
```javascript
const admin = require('firebase-admin');

// Generate live location link
const liveLocationLink = `https://www.google.com/maps?q=${latitude},${longitude}`;

// Prepare FCM payload (blueprint2 specification)
const notificationPayload = {
  notification: {
    title: '🚨 DRIVER SOS ALERT',
    body: `🚨 URGENT: Driver SOS! Immediate assistance requested at location ${liveLocationLink}`
  },
  data: {
    type: 'driver_sos',
    incident_id: incident.id,
    latitude: latitude.toString(),
    longitude: longitude.toString(),
    location_link: liveLocationLink,
    click_action: 'FLUTTER_NOTIFICATION_CLICK'
  },
  android: {
    priority: 'high',
    notification: {
      sound: 'default',
      channelId: 'driver_sos_alerts'
    }
  },
  apns: {
    payload: {
      aps: {
        sound: 'default',
        badge: 1
      }
    }
  }
};

// Send to all nearby drivers
const fcmTokens = nearbyDrivers.map(d => d.fcm_token).filter(t => t);
const notifiedDriverIds = [];

for (const driver of nearbyDrivers) {
  if (driver.fcm_token) {
    try {
      await admin.messaging().send({
        token: driver.fcm_token,
        ...notificationPayload
      });

      // Store notification in database
      await db.notifications.create({
        user_id: driver.id,
        title: notificationPayload.notification.title,
        body: notificationPayload.notification.body,
        type: 'driver_sos',
        data: JSON.stringify(notificationPayload.data),
        created_at: new Date().toISOString()
      });

      notifiedDriverIds.push(driver.id);
    } catch (error) {
      console.error(`Failed to send notification to driver ${driver.id}:`, error);
    }
  }
}
```

### Step 6: Update Incident with Notified Drivers
```javascript
// Update incident record
await db.sos_incidents
  .where({ id: incident.id })
  .update({
    notified_drivers: JSON.stringify(notifiedDriverIds),
    updated_at: new Date().toISOString()
  });
```

### Step 7: Alert Admin Dashboard
```javascript
// Send real-time update to admin dashboard via WebSocket
const adminAlert = {
  type: 'driver_sos',
  incident_id: incident.id,
  driver_id: driver_id,
  location: { latitude, longitude },
  location_link: liveLocationLink,
  notified_count: notifiedDriverIds.length,
  timestamp: new Date().toISOString()
};

// Emit to admin dashboard (using Socket.IO example)
io.to('admin-dashboard').emit('safety_alert', adminAlert);

// Also log to admin alerts table
await db.admin_alerts.create({
  type: 'driver_sos',
  severity: 'critical',
  data: JSON.stringify(adminAlert),
  created_at: new Date().toISOString()
});
```

### Step 8: Return Response
```javascript
return res.status(200).json({
  success: true,
  incident_id: incident.id,
  message: `SOS alert sent to ${notifiedDriverIds.length} nearby drivers`,
  notified_drivers_count: notifiedDriverIds.length,
  timestamp: new Date().toISOString()
});
```

## Complete Backend Implementation Example (Node.js/Express)

```javascript
const express = require('express');
const admin = require('firebase-admin');
const { authenticateDriver } = require('./middleware/auth');
const db = require('./database');

const router = express.Router();

router.post('/api/v1/driver/sos', authenticateDriver, async (req, res) => {
  try {
    const { driver_id, latitude, longitude, trip_id, incident_type } = req.body;

    // Step 1: Validation
    if (!driver_id || latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: driver_id, latitude, longitude',
        code: 'VALIDATION_ERROR'
      });
    }

    if (req.driver.id !== driver_id) {
      return res.status(403).json({
        success: false,
        error: 'Unauthorized',
        code: 'FORBIDDEN'
      });
    }

    // Step 2: Create SOS Incident
    const incident = await db.sos_incidents.create({
      user_id: driver_id,
      user_role: 'driver',
      trip_id: trip_id || null,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      incident_type: incident_type || 'emergency',
      status: 'active'
    });

    // Step 3: Get All Active Drivers
    const allActiveDrivers = await db.profiles
      .select('id', 'current_latitude', 'current_longitude', 'fcm_token')
      .where({ role: 'driver', is_online: true })
      .whereNotNull('current_latitude')
      .whereNotNull('current_longitude')
      .whereNot('id', driver_id);

    // Step 4: Geofencing Filter (5km radius)
    const RADIUS_KM = 5;
    const nearbyDrivers = allActiveDrivers.filter(driver => {
      const distance = calculateDistance(
        latitude,
        longitude,
        driver.current_latitude,
        driver.current_longitude
      );
      return distance <= RADIUS_KM;
    });

    // Step 5: Send FCM Push Notifications
    const liveLocationLink = `https://www.google.com/maps?q=${latitude},${longitude}`;
    const notifiedDriverIds = [];

    for (const driver of nearbyDrivers) {
      if (driver.fcm_token) {
        try {
          await admin.messaging().send({
            token: driver.fcm_token,
            notification: {
              title: '🚨 DRIVER SOS ALERT',
              body: `🚨 URGENT: Driver SOS! Immediate assistance requested at location ${liveLocationLink}`
            },
            data: {
              type: 'driver_sos',
              incident_id: incident.id,
              latitude: latitude.toString(),
              longitude: longitude.toString(),
              location_link: liveLocationLink
            },
            android: { priority: 'high' }
          });

          await db.notifications.create({
            user_id: driver.id,
            title: '🚨 DRIVER SOS ALERT',
            body: `🚨 URGENT: Driver SOS! Immediate assistance requested at location ${liveLocationLink}`,
            type: 'driver_sos',
            data: JSON.stringify({
              incident_id: incident.id,
              latitude,
              longitude,
              location_link: liveLocationLink
            })
          });

          notifiedDriverIds.push(driver.id);
        } catch (error) {
          console.error(`Failed to notify driver ${driver.id}:`, error);
        }
      }
    }

    // Step 6: Update Incident
    await db.sos_incidents
      .where({ id: incident.id })
      .update({ notified_drivers: JSON.stringify(notifiedDriverIds) });

    // Step 7: Alert Admin Dashboard
    const adminAlert = {
      type: 'driver_sos',
      incident_id: incident.id,
      driver_id,
      location: { latitude, longitude },
      location_link: liveLocationLink,
      notified_count: notifiedDriverIds.length,
      timestamp: new Date().toISOString()
    };

    // WebSocket emit (assuming Socket.IO)
    req.app.get('io').to('admin-dashboard').emit('safety_alert', adminAlert);

    await db.admin_alerts.create({
      type: 'driver_sos',
      severity: 'critical',
      data: JSON.stringify(adminAlert)
    });

    // Step 8: Return Response
    return res.status(200).json({
      success: true,
      incident_id: incident.id,
      message: `SOS alert sent to ${notifiedDriverIds.length} nearby drivers`,
      notified_drivers_count: notifiedDriverIds.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Driver SOS error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      code: 'INTERNAL_ERROR'
    });
  }
});

// Helper function
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

module.exports = router;
```

## Database Schema Requirements

### `sos_incidents` Table
```sql
CREATE TABLE sos_incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  user_role VARCHAR(20) NOT NULL, -- 'customer' or 'driver'
  trip_id UUID REFERENCES trips(id),
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  location_address TEXT,
  incident_type VARCHAR(50) DEFAULT 'emergency',
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'resolved', 'cancelled'
  notified_contacts JSONB, -- For passenger SOS
  notified_drivers JSONB, -- For driver SOS
  responding_users JSONB,
  resolved_at TIMESTAMP,
  resolved_by UUID REFERENCES profiles(id),
  resolution_notes TEXT,
  device_info JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sos_incidents_user ON sos_incidents(user_id);
CREATE INDEX idx_sos_incidents_status ON sos_incidents(status);
CREATE INDEX idx_sos_incidents_created ON sos_incidents(created_at);
```

### `notifications` Table
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(50) NOT NULL, -- 'driver_sos', 'trip_update', etc.
  data JSONB,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_read ON notifications(read);
```

### `admin_alerts` Table
```sql
CREATE TABLE admin_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(50) NOT NULL, -- 'driver_sos', 'system_error', etc.
  severity VARCHAR(20) NOT NULL, -- 'critical', 'high', 'medium', 'low'
  data JSONB,
  acknowledged BOOLEAN DEFAULT FALSE,
  acknowledged_by UUID REFERENCES profiles(id),
  acknowledged_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_admin_alerts_type ON admin_alerts(type);
CREATE INDEX idx_admin_alerts_severity ON admin_alerts(severity);
CREATE INDEX idx_admin_alerts_acknowledged ON admin_alerts(acknowledged);
```

## Security Considerations

1. **Rate Limiting**: Implement rate limiting to prevent SOS abuse (max 3 SOS per hour per driver)
2. **Authentication**: Always verify JWT token and driver identity
3. **Geolocation Validation**: Validate lat/long are within valid ranges
4. **FCM Token Management**: Handle expired/invalid tokens gracefully
5. **Logging**: Log all SOS incidents for audit trail
6. **Privacy**: Mask exact location in logs (reduce precision)

## Testing Checklist

- [ ] Test with valid driver credentials
- [ ] Test with invalid/expired JWT token
- [ ] Test with missing required fields
- [ ] Test with invalid coordinates
- [ ] Test with no nearby drivers
- [ ] Test with multiple nearby drivers
- [ ] Test FCM notification delivery
- [ ] Test admin dashboard alert
- [ ] Test database incident creation
- [ ] Test rate limiting (if implemented)
- [ ] Load test with multiple concurrent SOS requests

## Production Deployment Notes

1. Ensure Firebase Admin SDK is properly initialized
2. Configure FCM notification channels for Android
3. Set up WebSocket/Socket.IO for real-time admin alerts
4. Configure database indexes for performance
5. Set up monitoring and alerting for SOS endpoint
6. Test in DRC network conditions
7. Ensure proper error logging and tracking
