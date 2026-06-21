import 'dart:math';
import 'package:flutter/material.dart';
import '../models/template_settings.dart';
import '../providers/settings_provider.dart';

class GeotagOverlay extends StatelessWidget {
  final String address;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? heading;
  final String dateTimeStr;
  final String temperature;
  final String humidity;
  final String wind;
  final String pressure;
  final String template;
  final TemplateSettings? settings;
  final AppSettings? appSettings;

  const GeotagOverlay({
    Key? key,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.heading,
    required this.dateTimeStr,
    required this.temperature,
    required this.humidity,
    required this.wind,
    required this.pressure,
    required this.template,
    this.settings,
    this.appSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (template == 'minimal') {
      return _buildMinimalTemplate();
    } else if (template == 'sidebar-style') {
      return _buildSidebarTemplate();
    } else {
      return _buildDefaultTemplate(isModern: template == 'modern');
    }
  }

  // 1. Minimal Template
  Widget _buildMinimalTemplate() {
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Lat: ${latitude.toStringAsFixed(6)} | Long: ${longitude.toStringAsFixed(6)}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.0,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                "Temp: $temperature°C | Wind: $wind km/h",
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 10.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Sidebar Template (Top-Right)
  Widget _buildSidebarTemplate() {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: 170.0,
        margin: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              address,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const Divider(color: Colors.white24, height: 12.0),
            Text(
              "LAT: ${latitude.toStringAsFixed(6)}",
              style: const TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              "LNG: ${longitude.toStringAsFixed(6)}",
              style: const TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              dateTimeStr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 8.5,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              "Temp: $temperature °C",
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 9.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Default and Modern Templates
  Widget _buildDefaultTemplate({required bool isModern}) {
    final opts = settings ?? TemplateSettings();
    
    // Parse address logic: Title is usually the first component of the address.
    final parts = address.split(', ');
    final title = parts.isNotEmpty ? parts[0] : address;
    final remainingAddress = parts.length > 1 ? parts.skip(1).join(', ') : address;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, // Align to top
          children: [
            // Map / Satellite View
            if (opts.showMap) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 100.0,
                  height: 120.0, // Taller map like in the image
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Satellite Tile
                      Positioned.fill(
                        child: Image.network(
                          _getSatelliteTileUrl(latitude, longitude),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.satellite_alt,
                                color: Colors.white24,
                                size: 20.0,
                              ),
                            );
                          },
                        ),
                      ),
                      // Red pin in center
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 20.0,
                      ),
                      // Google logo at bottom left
                      Positioned(
                        left: 4.0,
                        bottom: 4.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 1.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                          child: const Text(
                            "Google",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 6.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
            ],

            // Right Column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Logo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (opts.showLogo) ...[
                        const SizedBox(width: 8.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFFFB300), size: 24.0),
                            const Text("Geo Tag Camera", style: TextStyle(color: Colors.white, fontSize: 8.0)),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4.0),

                  // Full or Short Address
                  if (opts.showFullAddress || opts.showShortAddress) ...[
                    Text(
                      opts.showFullAddress ? remainingAddress : (parts.length > 1 ? parts[1] : ""),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                  ],

                  // Lat / Long
                  if (opts.showLatLong) ...[
                    Text(
                      "Lat ${latitude.toStringAsFixed(6)} Long ${longitude.toStringAsFixed(6)}",
                      style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                  ],

                  // Plus Code
                  if (opts.showPlusCode) ...[
                    const Text(
                      "Plus Code : XMF6+MQ",
                      style: TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                  ],

                  // Date & Time + Timezone
                  if (opts.showDateTime || opts.showTimeZone) ...[
                    Text(
                      "${opts.showDateTime ? dateTimeStr : ''} ${opts.showTimeZone ? '(GMT +05:30)' : ''}".trim(),
                      style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                  ],

                  // Note
                  if (opts.showNote) ...[
                    Text(
                      "Note : ${opts.noteText}",
                      style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2.0),
                  ],
                  
                  // Person Name
                  if (opts.showPersonName) ...[
                    Text(
                      "By : ${opts.personNameText}",
                      style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4.0),
                  ],

                  const SizedBox(height: 6.0),

                  // Bottom Weather/Stats row
                  Wrap(
                    spacing: 12.0,
                    runSpacing: 4.0,
                    children: [
                      _buildIconText(Icons.air, "$wind km/h"),
                      _buildIconText(Icons.water_drop, "$humidity%"),
                      _buildIconText(Icons.terrain, "605 m", color: Colors.yellowAccent),
                      _buildIconText(Icons.explore, _getCompassDirection(heading), color: Colors.white70),
                      if (opts.showLogo) // Added weather next to logo like image
                        _buildIconText(Icons.wb_sunny, "$temperature°C", color: Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text, {Color color = Colors.lightBlueAccent}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12.0),
        const SizedBox(width: 4.0),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getCompassDirection(double? heading) {
    if (heading == null) return "N/A";
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = (((heading + 22.5) % 360) / 45).floor() % 8;
    return directions[index];
  }

  String _getSatelliteTileUrl(double lat, double lng, {int zoom = 16}) {
    final int n = pow(2, zoom).toInt();
    final double latRad = lat * pi / 180;
    final int x = ((lng + 180.0) / 360.0 * n).floor();
    final int y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor();
    return "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$zoom/$y/$x";
  }
}
