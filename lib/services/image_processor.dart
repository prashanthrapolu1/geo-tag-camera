import 'dart:io' show Directory, File, HttpClient;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gal/gal.dart';
import '../models/template_settings.dart';
import '../providers/settings_provider.dart';

class ImageProcessor {
  static Future<String> processAndSaveImage({
    required String inputPath,
    required Uint8List imageBytes,
    required String address,
    required double latitude,
    required double longitude,
    double? altitude,
    double? heading,
    required String dateTimeStr,
    required String temperature,
    required String humidity,
    required String wind,
    required String pressure,
    required String template,
    required String filterPreset,
    TemplateSettings? settings,
    AppSettings? appSettings,
    Uint8List? overlayBytes,
  }) async {
    // 1. Get image bytes
    final Uint8List bytes = imageBytes;

    // 2. Decode the image
    img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw Exception("Could not decode captured image.");
    }

    // 3. Apply Filter Preset
    decodedImage = _applyFilter(decodedImage, filterPreset);

    // Fetch and decode satellite tile image if template requires it
    img.Image? satelliteTile;
    if (template != 'minimal' && template != 'sidebar-style') {
      try {
        final client = HttpClient();
        final int n = pow(2, 16).toInt();
        final double latRad = latitude * pi / 180;
        final int x = ((longitude + 180.0) / 360.0 * n).floor();
        final int y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor();
        final tileUrl = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/16/$y/$x";
        
        final request = await client.getUrl(Uri.parse(tileUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          final tileBytes = await response.fold<List<int>>([], (p, e) => p..addAll(e));
          satelliteTile = img.decodeImage(Uint8List.fromList(tileBytes));
        }
      } catch (e) {
        print("Failed to fetch satellite tile: $e");
      }
    }

    // 4. Add Watermark/Geotag
    decodedImage = _drawGeoTagOverlay(
      image: decodedImage,
      address: address,
      lat: latitude,
      lng: longitude,
      dateTimeStr: dateTimeStr,
      temp: temperature,
      humidity: humidity,
      wind: wind,
      pressure: pressure,
      template: template,
      satelliteTile: satelliteTile,
      settings: settings,
      overlayBytes: overlayBytes,
    );

    // 5. Encode output as JPG
    final Uint8List outputBytes = img.encodeJpg(decodedImage, quality: 90);

    // 6. Save file (Mobile only)
    if (kIsWeb) {
      // On web, we don't save to a local gallery in this demo
      // You could implement IndexedDB or trigger a download here
      return "web_captured_image";
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String galleryDir = path.join(appDocDir.path, 'geotag_gallery');
    await Directory(galleryDir).create(recursive: true);

    final String fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String outputPath = path.join(galleryDir, fileName);
    
    final File outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes);

    // Save to device's shared gallery/photos storage
    try {
      await Gal.putImage(outputPath);
    } catch (e) {
      print("Failed to save image to shared gallery: $e");
    }

    return outputPath;
  }

  static img.Image _applyFilter(img.Image image, String preset) {
    switch (preset.toLowerCase()) {
      case 'chrome':
        // Modern chrome filter (boost color, contrast)
        return img.adjustColor(image, brightness: 1.1, contrast: 1.15, saturation: 1.3);
      case 'vintage':
        // Warm vintage sepia tone
        return img.sepia(image, amount: 0.5);
      case 'mono':
        // High contrast black & white
        return img.adjustColor(img.grayscale(image), contrast: 1.25);
      case 'warm':
        // Saturated warm tint
        return img.sepia(image, amount: 0.15);
      case 'cool':
        // Cool blueish adjustments
        return img.colorOffset(image, red: -10, blue: 15, green: -5);
      case 'default':
      default:
        return image;
    }
  }

  static img.Image _drawGeoTagOverlay({
    required img.Image image,
    required String address,
    required double lat,
    required double lng,
    required String dateTimeStr,
    required String temp,
    required String humidity,
    required String wind,
    required String pressure,
    required String template,
    img.Image? satelliteTile,
    TemplateSettings? settings,
    Uint8List? overlayBytes,
  }) {
    if (overlayBytes != null) {
      final img.Image? overlayImg = img.decodeImage(overlayBytes);
      if (overlayImg != null) {
        // High quality composite using the actual UI snapshot!
        final int targetW = (image.width * 0.95).round();
        final double ratio = targetW / overlayImg.width;
        final int targetH = (overlayImg.height * ratio).round();

        final img.Image scaledOverlay = img.copyResize(overlayImg, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
        
        final int targetX = (image.width - targetW) ~/ 2;
        final int targetY = image.height - targetH - targetX; // same margin on bottom
        
        img.compositeImage(image, scaledOverlay, dstX: targetX, dstY: targetY);
        return image;
      }
    }

    final int imgWidth = image.width;
    final int imgHeight = image.height;

    // Scale parameter to calculate target card dimensions on final high resolution image
    final double scale = imgWidth / 720.0;

    if (template == 'minimal') {
      // Create a virtual bar canvas matching base 720px width
      final int barW = 720;
      final int barH = 80;
      final img.Image barCanvas = img.Image(width: barW, height: barH);

      // Dark semitransparent background
      img.fillRect(
        barCanvas,
        x1: 0,
        y1: 0,
        x2: barW,
        y2: barH,
        color: img.ColorRgba8(0, 0, 0, 210),
      );

      // Render Text
      final String shortAddress = address.length > 50 ? "${address.substring(0, 47)}..." : address;
      img.drawString(
        barCanvas,
        shortAddress,
        font: img.arial24,
        x: 16,
        y: 12,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      final String stats = "LAT: ${lat.toStringAsFixed(6)} | LNG: ${lng.toStringAsFixed(6)} | TEMP: $temp°C | WIND: $wind km/h";
      img.drawString(
        barCanvas,
        stats,
        font: img.arial14,
        x: 16,
        y: 42,
        color: img.ColorRgba8(255, 179, 0, 255),
      );

      // Resize the virtual bar and composite
      final int targetW = imgWidth;
      final int targetH = (barH * scale).round();
      final int targetY = imgHeight - targetH;
      
      final img.Image scaledBar = img.copyResize(barCanvas, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
      img.compositeImage(image, scaledBar, dstX: 0, dstY: targetY);
      
      return image;
    }

    if (template == 'sidebar-style') {
      // Top right card
      final int cardW = 220;
      final int cardH = 260;
      final img.Image sidebarCanvas = img.Image(width: cardW, height: cardH);

      // Translucent Card
      img.fillRect(
        sidebarCanvas,
        x1: 0,
        y1: 0,
        x2: cardW,
        y2: cardH,
        color: img.ColorRgba8(0, 0, 0, 200),
      );

      // Border
      img.drawRect(
        sidebarCanvas,
        x1: 0,
        y1: 0,
        x2: cardW,
        y2: cardH,
        color: img.ColorRgba8(255, 255, 255, 50),
      );

      // Write contents vertically
      int currentY = 16;
      
      // Address (simple wrap)
      final List<String> addrLines = _wrapText(address, 20);
      for (var line in addrLines.take(3)) {
        img.drawString(
          sidebarCanvas,
          line,
          font: img.arial14,
          x: 12,
          y: currentY,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        currentY += 18;
      }

      currentY += 10;
      img.drawString(
        sidebarCanvas,
        "LAT: ${lat.toStringAsFixed(6)}",
        font: img.arial14,
        x: 12,
        y: currentY,
        color: img.ColorRgba8(255, 179, 0, 255),
      );
      currentY += 18;
      img.drawString(
        sidebarCanvas,
        "LNG: ${lng.toStringAsFixed(6)}",
        font: img.arial14,
        x: 12,
        y: currentY,
        color: img.ColorRgba8(255, 179, 0, 255),
      );

      currentY += 24;
      img.drawString(
        sidebarCanvas,
        dateTimeStr,
        font: img.arial14,
        x: 12,
        y: currentY,
        color: img.ColorRgba8(200, 200, 200, 255),
      );

      currentY += 24;
      img.drawString(
        sidebarCanvas,
        "TEMP: $temp °C",
        font: img.arial14,
        x: 12,
        y: currentY,
        color: img.ColorRgba8(100, 200, 255, 255),
      );

      // Resize and composite
      final int targetW = (cardW * scale).round();
      final int targetH = (cardH * scale).round();
      final int targetX = imgWidth - targetW - (20 * scale).round();
      final int targetY = (80 * scale).round();

      final img.Image scaledSidebar = img.copyResize(sidebarCanvas, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
      img.compositeImage(image, scaledSidebar, dstX: targetX, dstY: targetY);

      return image;
    }

    // Default & Modern templates
    final opts = settings ?? TemplateSettings();
    final int cardW = 700; 
    
    final parts = address.split(', ');
    final title = parts.isNotEmpty ? parts[0] : address;
    final remainingAddress = parts.length > 1 ? parts.skip(1).join(', ') : address;
    
    // Calculate required height dynamically
    int contentHeight = 24 + 32; // padding + title
    if (opts.showFullAddress || opts.showShortAddress) contentHeight += 40;
    if (opts.showLatLong) contentHeight += 24;
    if (opts.showPlusCode) contentHeight += 24;
    if (opts.showDateTime || opts.showTimeZone) contentHeight += 24;
    if (opts.showNote) contentHeight += 24;
    if (opts.showPersonName) contentHeight += 24;
    contentHeight += 12 + 30; // spacer + bottom row + padding

    final int cardH = max(280, contentHeight);
    
    final img.Image cardCanvas = img.Image(width: cardW, height: cardH);

    // Draw main translucent card (65% opacity background)
    img.fillRect(
      cardCanvas,
      x1: 0,
      y1: 0,
      x2: cardW,
      y2: cardH,
      color: img.ColorRgba8(0, 0, 0, 166),
    );

    final int mapSize = 220;
    final int mapX = 24;
    final int mapY = 24;

    if (opts.showMap) {
      if (satelliteTile != null) {
        img.compositeImage(
          cardCanvas,
          satelliteTile,
          dstX: mapX,
          dstY: mapY,
          dstW: mapSize,
          dstH: mapSize,
        );
      } else {
        // Map background fallback
        img.fillRect(
          cardCanvas,
          x1: mapX,
          y1: mapY,
          x2: mapX + mapSize,
          y2: mapY + mapSize,
          color: img.ColorRgba8(17, 24, 39, 255),
        );
      }
      
      // Pin
      final int pinCenterX = mapX + (mapSize ~/ 2);
      final int pinCenterY = mapY + (mapSize ~/ 2) - 6;
      img.fillCircle(
        cardCanvas,
        x: pinCenterX,
        y: pinCenterY,
        radius: 8,
        color: img.ColorRgba8(239, 68, 68, 255),
      );
      img.drawLine(
        cardCanvas,
        x1: pinCenterX,
        y1: pinCenterY,
        x2: pinCenterX,
        y2: pinCenterY + 16,
        color: img.ColorRgba8(239, 68, 68, 255),
        thickness: 4,
      );
    }

    final int textX = opts.showMap ? mapX + mapSize + 28 : 24;
    int textY = 24;

    // Title
    img.drawString(
      cardCanvas,
      title,
      font: img.arial24,
      x: textX,
      y: textY,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    
    // Logo
    if (opts.showLogo) {
      img.drawString(
        cardCanvas,
        "Nature House",
        font: img.arial14,
        x: cardW - 120,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }
    textY += 32;

    // Address
    if (opts.showFullAddress || opts.showShortAddress) {
      final addrStr = opts.showFullAddress ? remainingAddress : (parts.length > 1 ? parts[1] : "");
      final List<String> addrLines = _wrapText(addrStr, 40);
      for (var line in addrLines.take(2)) {
        img.drawString(
          cardCanvas,
          line,
          font: img.arial14,
          x: textX,
          y: textY,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        textY += 20;
      }
    }

    if (opts.showLatLong) {
      img.drawString(
        cardCanvas,
        "Lat ${lat.toStringAsFixed(6)} Long ${lng.toStringAsFixed(6)}",
        font: img.arial14,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += 24;
    }

    if (opts.showPlusCode) {
      img.drawString(
        cardCanvas,
        "Plus Code : XMF6+MQ",
        font: img.arial14,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += 24;
    }

    if (opts.showDateTime || opts.showTimeZone) {
      final dt = "${opts.showDateTime ? dateTimeStr : ''} ${opts.showTimeZone ? '(GMT +05:30)' : ''}".trim();
      img.drawString(
        cardCanvas,
        dt,
        font: img.arial14,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += 24;
    }

    if (opts.showNote) {
      img.drawString(
        cardCanvas,
        "Note : ${opts.noteText}",
        font: img.arial14,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += 24;
    }
    
    if (opts.showPersonName) {
      img.drawString(
        cardCanvas,
        "By : ${opts.personNameText}",
        font: img.arial14,
        x: textX,
        y: textY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      textY += 24;
    }

    textY += 12;

    // Bottom Stats row
    final statsStr = "$wind km/h  |  $humidity%  |  605 m  |  418 µT";
    img.drawString(
      cardCanvas,
      statsStr,
      font: img.arial14,
      x: textX,
      y: textY,
      color: img.ColorRgba8(240, 240, 240, 255),
    );

    // Resize and composite
    final int targetW = (cardW * scale).round();
    final int targetH = (cardH * scale).round();
    final int targetX = (20 * scale).round();
    final int targetY = imgHeight - targetH - (20 * scale).round();

    final img.Image scaledCard = img.copyResize(cardCanvas, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
    img.compositeImage(image, scaledCard, dstX: targetX, dstY: targetY);

    return image;
  }


  // Word-wrap helper
  static List<String> _wrapText(String text, int maxChars) {
    final List<String> lines = [];
    final List<String> words = text.split(' ');
    String currentLine = '';

    for (var word in words) {
      if ((currentLine + word).length > maxChars) {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine.trim());
        }
        currentLine = '$word ';
      } else {
        currentLine += '$word ';
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine.trim());
    }
    return lines;
  }
}
