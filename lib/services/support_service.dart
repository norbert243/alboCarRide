import 'package:supabase_flutter/supabase_flutter.dart';

class SupportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new support ticket/complaint
  Future<Map<String, dynamic>?> createSupportTicket({
    required String userId,
    required String userRole,
    required String subject,
    required String message,
    String? tripId,
    String? category,
  }) async {
    try {
      final response = await _supabase.from('support_tickets').insert({
        'user_id': userId,
        'user_role': userRole,
        'subject': subject,
        'message': message,
        'trip_id': tripId,
        'category': category ?? 'general',
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return response;
    } catch (e) {
      print('Error creating support ticket: $e');
      return null;
    }
  }

  /// Get all support tickets for a user
  Future<List<Map<String, dynamic>>> getUserTickets(String userId) async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select('*, trips:trip_id(pickup_address, dropoff_address)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user tickets: $e');
      return [];
    }
  }

  /// Get tickets for a specific trip
  Future<List<Map<String, dynamic>>> getTripTickets(String tripId) async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching trip tickets: $e');
      return [];
    }
  }

  /// Add a response to a ticket
  Future<bool> addTicketResponse({
    required String ticketId,
    required String responderId,
    required String message,
    bool isStaff = false,
  }) async {
    try {
      await _supabase.from('ticket_responses').insert({
        'ticket_id': ticketId,
        'responder_id': responderId,
        'message': message,
        'is_staff': isStaff,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update ticket status if staff responded
      if (isStaff) {
        await _supabase
            .from('support_tickets')
            .update({'status': 'in_progress'})
            .eq('id', ticketId);
      }

      return true;
    } catch (e) {
      print('Error adding ticket response: $e');
      return false;
    }
  }

  /// Close a ticket
  Future<bool> closeTicket(String ticketId) async {
    try {
      await _supabase
          .from('support_tickets')
          .update({
            'status': 'closed',
            'closed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticketId);
      return true;
    } catch (e) {
      print('Error closing ticket: $e');
      return false;
    }
  }

  /// Get user's recent trips for complaint linking
  Future<List<Map<String, dynamic>>> getUserRecentTrips(String userId, String role) async {
    try {
      final query = _supabase
          .from('ride_requests')
          .select('id, pickup_address, dropoff_address, created_at, status');

      final response = role == 'driver'
          ? await query.eq('driver_id', userId).order('created_at', ascending: false).limit(10)
          : await query.eq('rider_id', userId).order('created_at', ascending: false).limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching recent trips: $e');
      return [];
    }
  }

  /// Get support categories
  List<Map<String, String>> getSupportCategories() {
    return [
      {'id': 'general', 'name': 'General Inquiry'},
      {'id': 'trip_issue', 'name': 'Trip Issue'},
      {'id': 'payment', 'name': 'Payment Problem'},
      {'id': 'safety', 'name': 'Safety Concern'},
      {'id': 'driver_behavior', 'name': 'Driver Behavior'},
      {'id': 'rider_behavior', 'name': 'Rider Behavior'},
      {'id': 'app_bug', 'name': 'App Bug/Error'},
      {'id': 'account', 'name': 'Account Issue'},
      {'id': 'other', 'name': 'Other'},
    ];
  }
}
