import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:albocarride/widgets/custom_toast.dart';
import 'package:albocarride/widgets/rating_dialog.dart';

class RatingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Prompt user to rate a trip and submit the rating
  Future<void> promptRating({
    required BuildContext context,
    required String tripId,
    required String rateeId,
    String? driverName,
    String? vehicleType,
  }) async {
    try {
      // Show rating dialog
      final ratingData = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            RatingDialog(driverName: driverName, vehicleType: vehicleType),
      );

      if (ratingData == null) {
        // User skipped rating
        return;
      }

      final rating = ratingData['rating'] as int;
      final comment = ratingData['comment'] as String;

      // Submit rating to database
      final response = await _supabase.from('ratings').insert({
        'trip_id': tripId,
        'rater_id': _supabase.auth.currentUser!.id,
        'ratee_id': rateeId,
        'rating': rating,
        'comment': comment.isEmpty ? null : comment,
      });

      if (response.error != null) {
        CustomToast.show(
          context: context,
          message: 'Failed to submit rating: ${response.error!.message}',
        );
      } else {
        CustomToast.show(context: context, message: 'Thanks for your rating!');

        // Update driver's average rating
        await _updateDriverRating(rateeId);
      }
    } catch (e) {
      debugPrint('Error in rating flow: $e');
      CustomToast.show(
        context: context,
        message: 'Failed to submit rating. Please try again.',
      );
    }
  }

  /// Update driver's average rating after new rating submission
  Future<void> _updateDriverRating(String driverId) async {
    try {
      // Get all ratings for this driver
      final ratings = await _supabase
          .from('ratings')
          .select('rating')
          .eq('ratee_id', driverId);

      if (ratings.isEmpty) return;

      // Calculate new average
      final totalRatings = ratings.length;
      final sumRatings = ratings.fold<int>(
        0,
        (sum, rating) => sum + (rating['rating'] as int),
      );
      final averageRating = sumRatings / totalRatings;

      // Update driver's profile with new rating
      await _supabase
          .from('profiles')
          .update({'rating': averageRating, 'total_ratings': totalRatings})
          .eq('id', driverId);
    } catch (e) {
      debugPrint('Error updating driver rating: $e');
    }
  }

  /// Get ratings for a specific user
  Future<List<Map<String, dynamic>>> getUserRatings(String userId) async {
    try {
      final ratings = await _supabase
          .from('ratings')
          .select('*')
          .eq('ratee_id', userId)
          .order('created_at', ascending: false);

      return ratings.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error in getUserRatings: $e');
      return [];
    }
  }

  /// Get average rating for a user
  Future<double> getUserAverageRating(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('rating')
          .eq('id', userId)
          .single();

      return (profile['rating'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error in getUserAverageRating: $e');
      return 0.0;
    }
  }

  /// Check if user has already rated a specific trip
  Future<bool> hasRatedTrip(String tripId, String raterId) async {
    try {
      final ratings = await _supabase
          .from('ratings')
          .select('id')
          .eq('trip_id', tripId)
          .eq('rater_id', raterId);

      return ratings.isNotEmpty;
    } catch (e) {
      debugPrint('Error in hasRatedTrip: $e');
      return false;
    }
  }
}
