import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> getBytesFromAsset(String path, int width) async {
  final String svgStr = await rootBundle.loadString(path);
  final DrawableRoot svgDrawableRoot = await svg.fromSvgString(svgStr, svgStr);
  
  final ui.Picture picture = svgDrawableRoot.toPicture(size: Size(width.toDouble(), width.toDouble()));
  final ui.Image image = await picture.toImage(width, width);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}
