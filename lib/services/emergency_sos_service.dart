import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

/// Emergency contact
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final int priorityOrder;
  final bool notifyViaSms;
  final bool notifyViaWhatsapp;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    required this.priorityOrder,
    required this.notifyViaSms,
    required this.notifyViaWhatsapp,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phone_number'] as String,
      relationship: map['relationship'] as String?,
      priorityOrder: map['priority_order'] as int,
      notifyViaSms: map['notify_via_sms'] as bool,
      notifyViaWhatsapp: map['notify_via_whatsapp'] as bool,
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'relationship': relationship,
      'priority_order': priorityOrder,
      'notify_via_sms': notifyViaSms,
      'notify_via_whatsapp': notifyViaWhatsapp,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// SOS Incident
class SosIncident {
  final String id;
  final String userId;
  final String userRole;
  final String? tripId;
  final double latitude;
  final double longitude;
  final String? locationAddress;
  final String incidentType;
  final String status;
  final Map<String, dynamic>? notifiedContacts;
  final Map<String, dynamic>? notifiedDrivers;
  final Map<String, dynamic>? respondingUsers;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;
  final Map<String, dynamic>? deviceInfo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SosIncident({
    required this.id,
    required this.userId,
    required this.userRole,
    this.tripId,
    required this.latitude,
    required this.longitude,
    this.locationAddress,
    required this.incidentType,
    required this.status,
    this.notifiedContacts,
    this.notifiedDrivers,
    this.respondingUsers,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
    this.deviceInfo,
    required this.createdAt,
    this.updatedAt,
  });

  factory SosIncident.fromMap(Map<String, dynamic> map) {
    return SosIncident(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userRole: map['user_role'] as String,
      tripId: map['trip_id'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationAddress: map['location_address'] as String?,
      incidentType: map['incident_type'] as String,
      status: map['status'] as String,
      notifiedContacts: map['notified_contacts'] as Map<String, dynamic>?,
      notifiedDrivers: map['notified_drivers'] as Map<String, dynamic>?,
      respondingUsers: map['responding_users'] as Map<String, dynamic>?,
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'] as String)
          : null,
      resolvedBy: map['resolved_by'] as String?,
      resolutionNotes: map['resolution_notes'] as String?,
      deviceInfo: map['device_info'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}

/// Service for emergency SOS functionality
class EmergencySosService {
  final SupabaseClient _supabase;

  EmergencySosService(this._supabase);

  // ========== Emergency Contacts Management ==========

  /// Get all emergency contacts for a user
  Future<List<EmergencyContact>> getEmergencyContacts(String userId) async {
    try {
      final response = await _supabase
          .from('emergency_contacts')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('priority_order');

      return (response as List)
          .map((contact) => EmergencyContact.fromMap(contact))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch emergency contacts: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching emergency contacts: $e');
    }
  }

  /// Add an emergency contact
  Future<EmergencyContact> addEmergencyContact({
    required String userId,
    required String name,
    required String phoneNumber,
    String? relationship,
    required int priorityOrder,
    bool notifyViaSms = true,
    bool notifyViaWhatsapp = true,
  }) async {
    try {
      final response = await _supabase
          .from('emergency_contacts')
          .insert({
            'user_id': userId,
            'name': name,
            'phone_number': phoneNumber,
            'relationship': relationship,
            'priority_order': priorityOrder,
            'notify_via_sms': notifyViaSms,
            'notify_via_whatsapp': notifyViaWhatsapp,
          })
          .select()
          .single();

      return EmergencyContact.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to add emergency contact: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding emergency contact: $e');
    }
  }

  /// Update an emergency contact
  Future<EmergencyContact> updateEmergencyContact({
    required String contactId,
    String? name,
    String? phoneNumber,
    String? relationship,
    int? priorityOrder,
    bool? notifyViaSms,
    bool? notifyViaWhatsapp,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (relationship != null) updateData['relationship'] = relationship;
      if (priorityOrder != null) updateData['priority_order'] = priorityOrder;
      if (notifyViaSms != null) updateData['notify_via_sms'] = notifyViaSms;
      if (notifyViaWhatsapp != null) {
        updateData['notify_via_whatsapp'] = notifyViaWhatsapp;
      }
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('emergency_contacts')
          .update(updateData)
          .eq('id', contactId)
          .select()
          .single();

      return EmergencyContact.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update emergency contact: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating emergency contact: $e');
    }
  }

  /// Delete an emergency contact
  Future<void> deleteEmergencyContact(String contactId) async {
    try {
      await _supabase.from('emergency_contacts').delete().eq('id', contactId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete emergency contact: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting emergency contact: $e');
    }
  }

  // ========== SOS Trigger ==========

  /// Trigger passenger SOS (sends to emergency contacts)
  Future<SosIncident> triggerPassengerSos({
    required String userId,
    required Position currentLocation,
    String? tripId,
    String incidentType = 'emergency',
  }) async {
    try {
      // Get emergency contacts
      final contacts = await getEmergencyContacts(userId);

      if (contacts.isEmpty) {
        throw Exception(
          'No emergency contacts configured. Please add contacts first.',
        );
      }

      // Create SOS incident
      final incident = await _createSosIncident(
        userId: userId,
        userRole: 'customer',
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        tripId: tripId,
        incidentType: incidentType,
      );

      // Send notifications to emergency contacts
      final notifiedContacts = <String>[];
      for (final contact in contacts) {
        await _notifyEmergencyContact(
          contact: contact,
          location: currentLocation,
          incidentId: incident.id,
        );
        notifiedContacts.add(contact.id);
      }

      // Update incident with notified contacts
      await _updateIncidentNotifications(
        incidentId: incident.id,
        notifiedContacts: notifiedContacts,
      );

      return incident;
    } catch (e) {
      throw Exception('Failed to trigger passenger SOS: $e');
    }
  }

  /// Trigger driver SOS (sends to nearby drivers)
  Future<SosIncident> triggerDriverSos({
    required String userId,
    required Position currentLocation,
    String? tripId,
    String incidentType = 'emergency',
  }) async {
    try {
      // Create SOS incident
      final incident = await _createSosIncident(
        userId: userId,
        userRole: 'driver',
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        tripId: tripId,
        incidentType: incidentType,
      );

      // Get nearby drivers (3-5 km radius)
      final nearbyDrivers = await _getNearbyDrivers(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radiusKm: 5.0,
      );

      // Send push notifications to nearby drivers
      final notifiedDrivers = <String>[];
      for (final driver in nearbyDrivers) {
        await _sendDriverSosNotification(
          driverId: driver['id'] as String,
          sosLocation: currentLocation,
          incidentId: incident.id,
        );
        notifiedDrivers.add(driver['id'] as String);
      }

      // Update incident with notified drivers
      await _updateIncidentNotifications(
        incidentId: incident.id,
        notifiedDrivers: notifiedDrivers,
      );

      return incident;
    } catch (e) {
      throw Exception('Failed to trigger driver SOS: $e');
    }
  }

  /// Create SOS incident in database
  Future<SosIncident> _createSosIncident({
    required String userId,
    required String userRole,
    required double latitude,
    required double longitude,
    String? tripId,
    String incidentType = 'emergency',
  }) async {
    try {
      final response = await _supabase
          .from('sos_incidents')
          .insert({
            'user_id': userId,
            'user_role': userRole,
            'trip_id': tripId,
            'latitude': latitude,
            'longitude': longitude,
            'incident_type': incidentType,
            'status': 'active',
          })
          .select()
          .single();

      return SosIncident.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create SOS incident: ${e.message}');
    }
  }

  /// Notify emergency contact via SMS/WhatsApp
  Future<void> _notifyEmergencyContact({
    required EmergencyContact contact,
    required Position location,
    required String incidentId,
  }) async {
    final googleMapsLink =
        'https://www.google.com/maps?q=${location.latitude},${location.longitude}';

    final message = '''🚨 EMERGENCY ALERT 🚨

${contact.name}, this is an automated emergency alert from AlboCarRide.

A passenger has triggered an SOS alert at:
📍 Location: $googleMapsLink

Please check on them immediately or contact local authorities.

Alert ID: $incidentId
Time: ${DateTime.now().toString()}''';

    // Send via WhatsApp if enabled
    if (contact.notifyViaWhatsapp) {
      await _sendWhatsAppMessage(contact.phoneNumber, message);
    }

    // Send via SMS if enabled
    if (contact.notifyViaSms) {
      await _sendSmsMessage(contact.phoneNumber, message);
    }
  }

  /// Send WhatsApp message
  Future<void> _sendWhatsAppMessage(String phoneNumber, String message) async {
    try {
      final whatsappUrl = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Failed to send WhatsApp message: $e');
    }
  }

  /// Send SMS message
  Future<void> _sendSmsMessage(String phoneNumber, String message) async {
    try {
      final smsUrl = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      }
    } catch (e) {
      print('Failed to send SMS: $e');
    }
  }

  /// Get nearby drivers within radius
  Future<List<Map<String, dynamic>>> _getNearbyDrivers({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    try {
      // Get all online drivers
      final response = await _supabase
          .from('profiles')
          .select('id, current_latitude, current_longitude')
          .eq('role', 'driver')
          .eq('is_online', true)
          .not('current_latitude', 'is', null)
          .not('current_longitude', 'is', null);

      // Filter by distance
      final nearbyDrivers = <Map<String, dynamic>>[];
      for (final driver in response as List) {
        final driverLat = (driver['current_latitude'] as num).toDouble();
        final driverLng = (driver['current_longitude'] as num).toDouble();

        final distance = Geolocator.distanceBetween(
              latitude,
              longitude,
              driverLat,
              driverLng,
            ) /
            1000; // Convert to km

        if (distance <= radiusKm) {
          nearbyDrivers.add(driver);
        }
      }

      return nearbyDrivers;
    } catch (e) {
      print('Failed to get nearby drivers: $e');
      return [];
    }
  }

  /// Send SOS notification to driver via push notification
  Future<void> _sendDriverSosNotification({
    required String driverId,
    required Position sosLocation,
    required String incidentId,
  }) async {
    try {
      // Create notification record
      await _supabase.from('notifications').insert({
        'user_id': driverId,
        'title': '🚨 DRIVER SOS ALERT',
        'body':
            'A fellow driver needs help nearby! Tap to view location and assist.',
        'type': 'driver_sos',
        'data': jsonEncode({
          'incident_id': incidentId,
          'latitude': sosLocation.latitude,
          'longitude': sosLocation.longitude,
        }),
      });

      // TODO: Trigger actual push notification via FCM
      // This would be handled by your notification service
    } catch (e) {
      print('Failed to send driver SOS notification: $e');
    }
  }

  /// Update incident with notified contacts/drivers
  Future<void> _updateIncidentNotifications({
    required String incidentId,
    List<String>? notifiedContacts,
    List<String>? notifiedDrivers,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (notifiedContacts != null) {
        updateData['notified_contacts'] = jsonEncode(notifiedContacts);
      }
      if (notifiedDrivers != null) {
        updateData['notified_drivers'] = jsonEncode(notifiedDrivers);
      }

      await _supabase
          .from('sos_incidents')
          .update(updateData)
          .eq('id', incidentId);
    } catch (e) {
      print('Failed to update incident notifications: $e');
    }
  }

  /// Resolve SOS incident
  Future<SosIncident> resolveSosIncident({
    required String incidentId,
    required String resolvedBy,
    String? resolutionNotes,
  }) async {
    try {
      final response = await _supabase
          .from('sos_incidents')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': resolvedBy,
            'resolution_notes': resolutionNotes,
          })
          .eq('id', incidentId)
          .select()
          .single();

      return SosIncident.fromMap(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to resolve SOS incident: ${e.message}');
    }
  }

  /// Get active SOS incidents for a user
  Future<List<SosIncident>> getActiveSosIncidents(String userId) async {
    try {
      final response = await _supabase
          .from('sos_incidents')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List)
          .map((incident) => SosIncident.fromMap(incident))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch active SOS incidents: ${e.message}');
    }
  }

  /// Get SOS incident history
  Future<List<SosIncident>> getSosIncidentHistory(String userId) async {
    try {
      final response = await _supabase
          .from('sos_incidents')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((incident) => SosIncident.fromMap(incident))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch SOS incident history: ${e.message}');
    }
  }
}
