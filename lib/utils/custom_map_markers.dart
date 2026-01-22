import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Custom map markers for cars and persons
class CustomMapMarkers {
  static BitmapDescriptor? _carMarkerGreen;
  static BitmapDescriptor? _carMarkerOrange;
  static BitmapDescriptor? _carMarkerPurple;
  static BitmapDescriptor? _carMarkerBlue;
  static BitmapDescriptor? _personMarker;
  static BitmapDescriptor? _pickupMarker;
  static BitmapDescriptor? _dropoffMarker;

  /// Initialize all custom markers
  static Future<void> initialize() async {
    _carMarkerGreen = await _createCarMarker(Colors.green);
    _carMarkerOrange = await _createCarMarker(Colors.orange);
    _carMarkerPurple = await _createCarMarker(Colors.purple);
    _carMarkerBlue = await _createCarMarker(Colors.blue);
    _personMarker = await _createPersonMarker(Colors.deepPurple);
    _pickupMarker = await _createLocationMarker(Colors.green, Icons.trip_origin);
    _dropoffMarker = await _createLocationMarker(Colors.red, Icons.flag);
  }

  /// Get car marker based on vehicle type
  static BitmapDescriptor getCarMarker(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'suv':
        return _carMarkerOrange ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'luxury':
        return _carMarkerPurple ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case 'comfort':
        return _carMarkerBlue ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      default:
        return _carMarkerGreen ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  /// Get person marker for riders
  static BitmapDescriptor getPersonMarker() {
    return _personMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }

  /// Get pickup location marker
  static BitmapDescriptor getPickupMarker() {
    return _pickupMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  /// Get dropoff location marker
  static BitmapDescriptor getDropoffMarker() {
    return _dropoffMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  /// Create a custom car marker
  static Future<BitmapDescriptor> _createCarMarker(Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = const Size(80, 80);

    // Draw circle background
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 4,
      bgPaint,
    );

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 4,
      borderPaint,
    );

    // Draw car icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_car.codePoint),
        style: TextStyle(
          fontSize: 40,
          fontFamily: Icons.directions_car.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Create a custom person marker for riders
  static Future<BitmapDescriptor> _createPersonMarker(Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = const Size(70, 70);

    // Draw circle background
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 3,
      bgPaint,
    );

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 3,
      borderPaint,
    );

    // Draw person icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.person.codePoint),
        style: TextStyle(
          fontSize: 36,
          fontFamily: Icons.person.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Create a location marker (pickup/dropoff)
  static Future<BitmapDescriptor> _createLocationMarker(Color color, IconData icon) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = const Size(60, 60);

    // Draw circle background
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 2,
      bgPaint,
    );

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 2,
      borderPaint,
    );

    // Draw icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 30,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
