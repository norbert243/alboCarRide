import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String? driverName;
  final String? vehicleType;

  const RatingDialog({super.key, this.driverName, this.vehicleType});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  final bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Rate Your Trip',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.driverName != null || widget.vehicleType != null) ...[
              Text(
                'How was your ride with ${widget.driverName ?? 'the driver'}?',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Tap a star to rate:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Star Rating
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = starIndex;
                      });
                    },
                    child: Icon(
                      starIndex <= _selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      size: 40,
                      color: starIndex <= _selectedRating
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Rating Labels
            Center(
              child: Text(
                _getRatingLabel(_selectedRating),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _getRatingColor(_selectedRating),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Comment Section
            const Text(
              'Add a comment (optional):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop(null);
                },
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedRating == 0
              ? null
              : () {
                  Navigator.of(context).pop({
                    'rating': _selectedRating,
                    'comment': _commentController.text.trim(),
                  });
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap to rate';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
