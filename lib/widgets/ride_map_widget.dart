import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

/// A reusable widget for displaying a Google Map with ride information
class RideMapWidget extends StatefulWidget {
  final double? currentLat;
  final double? currentLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? pickupAddress;
  final String? dropoffAddress;
  final List<LatLng>? polylinePoints;
  final double height;
  final bool showCurrentLocation;

  const RideMapWidget({
    super.key,
    this.currentLat,
    this.currentLng,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupAddress,
    this.dropoffAddress,
    this.polylinePoints,
    this.height = 300,
    this.showCurrentLocation = true,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void didUpdateWidget(RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update markers when widget properties change
    if (oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.dropoffLat != widget.dropoffLat ||
        oldWidget.dropoffLng != widget.dropoffLng) {
      _updateMarkers();
      _updatePolylines();
      _animateToShowAllMarkers();
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      print('Could not load map style: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
    _updateMarkers();
    _updatePolylines();
    _animateToShowAllMarkers();
  }

  void _updateMarkers() {
    _markers.clear();

    // Add current location marker
    if (widget.showCurrentLocation &&
        widget.currentLat != null &&
        widget.currentLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(widget.currentLat!, widget.currentLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Add pickup marker
    if (widget.pickupLat != null && widget.pickupLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.pickupLat!, widget.pickupLng!),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: widget.pickupAddress,
          ),
        ),
      );
    }

    // Add dropoff marker
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(widget.dropoffLat!, widget.dropoffLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff',
            snippet: widget.dropoffAddress,
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updatePolylines() {
    _polylines.clear();

    if (widget.polylinePoints != null && widget.polylinePoints!.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.polylinePoints!,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _animateToShowAllMarkers() async {
    if (_mapController == null || _markers.isEmpty) return;

    // Calculate bounds to show all markers
    double? minLat, maxLat, minLng, maxLng;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat != null &&
        maxLat != null &&
        minLng != null &&
        maxLng != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Add padding to the bounds
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } else if (_markers.isNotEmpty) {
      // If only one marker, center on it
      final marker = _markers.first;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(marker.position, 15),
      );
    }
  }

  LatLng _getInitialPosition() {
    // Prioritize pickup location
    if (widget.pickupLat != null && widget.pickupLng != null) {
      return LatLng(widget.pickupLat!, widget.pickupLng!);
    }
    // Then current location
    if (widget.currentLat != null && widget.currentLng != null) {
      return LatLng(widget.currentLat!, widget.currentLng!);
    }
    // Default to a general location (e.g., center of South Africa)
    return const LatLng(-29.0, 24.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _getInitialPosition(),
            zoom: 13,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: widget.showCurrentLocation,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          buildingsEnabled: true,
          trafficEnabled: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
