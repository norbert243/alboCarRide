
# Driver UI Implementation Specification

## Pixel-Level Design Specifications

### 1. Driver Home Screen Components

#### **Primary Action Button**
```dart
Container(
  width: 280, // Fixed width for consistency
  height: 60,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: isOnline 
        ? [Color(0xFF00C853), Color(0xFF00E676)] // Green gradient
        : [Color(0xFFFF3D00), Color(0xFFFF6E40)], // Red gradient
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: isOnline 
          ? Color(0xFF00C853).withOpacity(0.4)
          : Color(0xFFFF3D00).withOpacity(0.4),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: Stack(
    children: [
      // Pulsing animation for online state
      if (isOnline) ...[
        Positioned.fill(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 1500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
      Center(
        child: Text(
          isOnline ? 'GO OFFLINE' : 'GO ONLINE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ],
  ),
)
```

#### **Earnings Dashboard Card**
```dart
Container(
  width: double.infinity,
  height: 120,
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _buildEarningItem(
        icon: Icons.attach_money_rounded,
        value: 'R245.50',
        label: 'Today',
        color: Color(0xFF00C853),
      ),
      _buildEarningItem(
        icon: Icons.directions_car_rounded,
        value: '8',
        label: 'Rides',
        color: Color(0xFF2196F3),
      ),
      _buildEarningItem(
        icon: Icons.star_rounded,
        value: '4.8',
        label: 'Rating',
        color: Color(0xFFFFC107),
      ),
    ],
  ),
)

Widget _buildEarningItem({
  required IconData icon,
  required String value,
  required String label,
  required Color color,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey[600],
        ),
      ),
    ],
  );
}
```

### 2. Incoming Ride Request Modal

#### **Modal Container**
```dart
class RideRequestModal extends StatefulWidget {
  final Map<String, dynamic> rideRequest;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  
  const RideRequestModal({
    Key? key,
    required this.rideRequest,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);
  
  @override
  _RideRequestModalState createState() => _RideRequestModalState();
}

class _RideRequestModalState extends State<RideRequestModal> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  int _countdown = 15;
  Timer? _countdownTimer;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _controller.forward();
    _startCountdown();
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _autoDecline();
      }
    });
  }
  
  void _autoDecline() {
    _countdownTimer?.cancel();
    widget.onDecline();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with countdown
            _buildHeader(),
            // Passenger info
            _buildPassengerInfo(),
            // Route details
            _buildRouteDetails(),
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_car_rounded, color: Color(0xFF2196F3)),
          SizedBox(width: 8),
          Text(
            'New Ride Request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_countdown',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPassengerInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: Color(0xFF2196F3)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rideRequest['passenger_name'] ?? 'Passenger',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                    SizedBox(width: 4),
                    Text(
                      widget.rideRequest['rating']?.toString() ?? '4.8',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRouteDetails() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.location_on_rounded,
            text: widget.rideRequest['pickup_address'] ?? 'Pickup location',
            color: Color(0xFF4CAF50),
          ),
          SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.flag_rounded,
            text: widget.rideRequest['dropoff_address'] ?? 'Dropoff location',
            color: Color(0xFFF44336),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFareDetail('Fare', 'R${widget.rideRequest['fare'] ?? '0.00'}'),
                _buildFareDetail('Distance', '${widget.rideRequest['distance'] ?? '0'}km'),
                _buildFareDetail('Time', '${widget.rideRequest['duration'] ?? '0'}min'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFareDetail(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () {
                _countdownTimer?.cancel();
                widget.onAccept();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'ACCEPT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                _countdownTimer?.cancel();
                widget.onDecline();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFFFF3D00),
                side: BorderSide(color: Color(0xFFFF3D00)),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DECLINE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 3. Enhanced Ride Matching Algorithm

#### **Smart Matching Service**
```dart
class EnhancedRideMatchingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Future<List<Map<String, dynamic>>> findEligibleDrivers({
    required double pickupLat,
    required double pickupLng,
    String? vehicleType,
    double? minFare,
    double? maxDistance = 5.0,
    double? minRating = 4.0,
  }) async {
    // Get drivers within maximum distance
    final nearbyDrivers = await _findNearbyDrivers(
      pickupLat,
      pickupLng,
      maxDistance: maxDistance,
    );
    
    // Apply filters and scoring
    final eligibleDrivers = await _scoreAndFilterDrivers(
      drivers: nearbyDrivers,
      vehicleType: vehicleType,
      minFare: minFare,
      minRating: minRating,
    );
    
    // Sort by priority score
    eligibleDrivers.sort((a, b) => 
      (b['priority_score'] as double).compareTo(a['priority_score'] as double)
    );
    
    return eligibleDrivers;
  }
  
  Future<List<Map<String, dynamic>>> _scoreAndFilterDrivers({
    required List<Map<String, dynamic>> drivers,
    String? vehicleType,
    double? minFare,
    double? minRating,
  }) async {
    final List<Map<String, dynamic>> scoredDrivers = [];
    
    for (final driver in drivers) {
      double score = 0.0;
      
      // Distance score (closer is better)
      final distance = driver['distance'] as double;
      score += (1 - (distance / 5.0)) * 40; // 40% weight
      
      // Rating score
      final rating = driver['rating'] as double? ?? 0.0;
      score += (rating / 5.0) * 30; // 30% weight
      
      // Acceptance rate score
      final acceptanceRate = await _getDriverAcceptanceRate(driver['id']);
      score += (acceptanceRate / 100.0) * 20; // 20% weight
      
      // Response time score (faster is better)
      final avgResponseTime = await _getAvgResponseTime(driver['id']);
      final responseScore = 1 - (avgResponseTime / 60.0); // Normalize to 60 seconds
      score += responseScore.clamp(0, 1) * 10; // 10% weight
      
      // Apply filters
      if (vehicleType != null && driver['vehicle_type'] != vehicleType) {
        continue;
      }
      
      if (minRating != null && rating < minRating) {
        continue;
      }
      
      scoredDrivers.add({
        ...driver,
        'priority_score': score,
        'acceptance_rate': acceptanceRate,
        'avg_response_time': avgResponseTime,
      });
    }
    
    return scoredDrivers;
  }
  
  Future<double> _getDriverAcceptanceRate(String driverId) async {
    final response = await _supabase
        .from('ride_offers')
        .select('status')
        .eq('driver_id', driverId);
    
    final totalOffers = response.length;
    final acceptedOffers = response.where((offer) => 
      offer['status'] == 'accepted').length;
    
    return totalOffers > 0 ? (acceptedOffers / totalOffers) * 100 : 100.0;
  }
  
  Future<double> _getAvgResponseTime(String driverId) async {
    final response = await _supabase
        .from('ride_offers')
        .select('created_at, accepted_at')
        .eq('driver_id', driverId)
        .eq('status', 'accepted');
    
    if (response.isEmpty) return 15.0; // Default 15 seconds
    
    double totalResponseTime = 0.0;
    int count = 0;
    
    for (final offer in response) {
      final createdAt = DateTime.parse(offer['created_at']);
      final acceptedAt = DateTime.parse(offer['accepted_at']);
      final responseTime = acceptedAt.difference(createdAt).inSeconds;
      
      totalResponseTime += responseTime;
      count++;
    }
    
    return count > 0 ? totalResponseTime / count : 15.0;
  }
}
```

### 4. Loading States and Error Handling

#### **Loading Component**
```dart
class DriverLoadingState extends Stateless