import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg; // Alias flutter_svg
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> getBytesFromAsset(String path, int width) async {
  final String svgString = await rootBundle.loadString(path);
  
  // Load the SVG string into a PictureInfo object
  final svg.PictureInfo pictureInfo = await svg.vg.loadPicture(
    svg.SvgStringLoader(svgString),
    null, // No ColorFilter needed for this use case
  );

  // Define the scaled dimensions based on the desired width and device pixel ratio.
  final double devicePixelRatio = ui.window.devicePixelRatio;
  final double scaledWidth = width * devicePixelRatio;
  final double scaledHeight = width * devicePixelRatio; // Assuming square icons

  // Convert the ui.Picture to a ui.Image
  final ui.Image image = await pictureInfo.picture.toImage(
    scaledWidth.toInt(),
    scaledHeight.toInt(),
  );

  // Convert the ui.Image to ByteData in PNG format.
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  if (bytes == null) {
    throw Exception('Unable to convert SVG to PNG bytes.');
  }

  // Return the BitmapDescriptor from the byte data.
  return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
}