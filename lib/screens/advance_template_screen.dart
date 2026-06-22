import 'package:flutter/material.dart';
import '../models/template_settings.dart';
import '../widgets/geotag_overlay.dart';

class AdvanceTemplateScreen extends StatefulWidget {
  final TemplateSettings initialSettings;
  final String address;
  final double latitude;
  final double longitude;
  final String dateTimeStr;
  final String? temperature;
  final String? humidity;
  final String? wind;
  final String? pressure;

  const AdvanceTemplateScreen({
    Key? key,
    required this.initialSettings,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.dateTimeStr,
    this.temperature,
    this.humidity,
    this.wind,
    this.pressure,
  }) : super(key: key);

  @override
  _AdvanceTemplateScreenState createState() => _AdvanceTemplateScreenState();
}

class _AdvanceTemplateScreenState extends State<AdvanceTemplateScreen> {
  late TemplateSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings.copyWith();
  }

  void _toggleSetting(String key, bool value) {
    setState(() {
      switch (key) {
        case 'map':
          _settings.showMap = value;
          break;
        case 'shortAddress':
          _settings.showShortAddress = value;
          break;
        case 'fullAddress':
          _settings.showFullAddress = value;
          break;
        case 'latLong':
          _settings.showLatLong = value;
          break;
        case 'plusCode':
          _settings.showPlusCode = value;
          break;
        case 'dateTime':
          _settings.showDateTime = value;
          break;
        case 'timeZone':
          _settings.showTimeZone = value;
          break;
        case 'numbering':
          _settings.showNumbering = value;
          break;
        case 'logo':
          _settings.showLogo = value;
          break;
        case 'note':
          _settings.showNote = value;
          break;
        case 'personName':
          _settings.showPersonName = value;
          break;
        case 'weather':
          _settings.showWeather = value;
          break;
        case 'altitude':
          _settings.showAltitude = value;
          break;
        case 'compass':
          _settings.showCompass = value;
          break;
      }
    });
  }

  Future<void> _editTextField(String title, String currentValue, Function(String) onSave) async {
    TextEditingController controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Enter $title"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required bool value,
    required String key,
    required Widget trailing,
  }) {
    return InkWell(
      onTap: () => _toggleSetting(key, !value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 22.0,
              height: 22.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? const Color(0xFFFFB300) : Colors.transparent,
                border: Border.all(
                  color: value ? const Color(0xFFFFB300) : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: Colors.white, size: 14.0)
                  : null,
            ),
            const SizedBox(width: 16.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.0,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _settings);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            "Advance Template",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20.0),
            onPressed: () => Navigator.pop(context, _settings),
          ),
        ),
        body: Column(
          children: [
            // Preview Section
            Container(
              width: double.infinity,
              color: const Color(0xFFF5F5F5),
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  color: Colors.transparent,
                  // We show the actual GeotagOverlay but in preview mode
                  child: GeotagOverlay(
                    address: widget.address,
                    latitude: widget.latitude,
                    longitude: widget.longitude,
                    dateTimeStr: widget.dateTimeStr,
                    temperature: widget.temperature,
                    humidity: widget.humidity,
                    wind: widget.wind,
                    pressure: widget.pressure,
                    template: 'default',
                    settings: _settings,
                  ),
                ),
              ),
            ),

            // Divider
            const Divider(height: 1.0, color: Color(0xFFEEEEEE)),

            // Settings List
            Expanded(
              child: ListView(
                children: [
                  _buildToggleItem(
                    title: "Map Type",
                    key: 'map',
                    value: _settings.showMap,
                    trailing: Container(
                      width: 24.0,
                      height: 24.0,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                      ),
                      child: const Icon(Icons.map, size: 14.0, color: Colors.white),
                    ),
                  ),
                  _buildToggleItem(
                    title: "Short Address",
                    key: 'shortAddress',
                    value: _settings.showShortAddress,
                    trailing: const Text("Automatic", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Full Address",
                    key: 'fullAddress',
                    value: _settings.showFullAddress,
                    trailing: const Text("Automatic", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Lat / Long",
                    key: 'latLong',
                    value: _settings.showLatLong,
                    trailing: Text(
                      "Lat ${widget.latitude.toStringAsFixed(6)} Long ${widget.longitude.toStringAsFixed(6)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                    ),
                  ),
                  _buildToggleItem(
                    title: "Plus Code",
                    key: 'plusCode',
                    value: _settings.showPlusCode,
                    trailing: const Text("XMF6+MQ", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Date & Time",
                    key: 'dateTime',
                    value: _settings.showDateTime,
                    trailing: const Text("11/07/24 10:51 AM", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Time Zone",
                    key: 'timeZone',
                    value: _settings.showTimeZone,
                    trailing: const Text("GMT +05:30", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Numbring",
                    key: 'numbering',
                    value: _settings.showNumbering,
                    trailing: const Text("1", style: TextStyle(color: Colors.grey, fontSize: 13.0)),
                  ),
                  _buildToggleItem(
                    title: "Logo",
                    key: 'logo',
                    value: _settings.showLogo,
                    trailing: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 20.0),
                  ),
                  _buildToggleItem(
                    title: "Note / Hashtag",
                    key: 'note',
                    value: _settings.showNote,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _settings.noteText.isEmpty ? "Empty" : (_settings.noteText.length > 20 ? "${_settings.noteText.substring(0, 17)}..." : _settings.noteText),
                          style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                        ),
                        const SizedBox(width: 8.0),
                        InkWell(
                          onTap: () => _editTextField("Note / Hashtag", _settings.noteText, (val) {
                            setState(() {
                              _settings.noteText = val;
                              _settings.showNote = val.isNotEmpty;
                            });
                          }),
                          child: const Icon(Icons.edit, size: 16.0, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),
                  _buildToggleItem(
                    title: "Person Name",
                    key: 'personName',
                    value: _settings.showPersonName,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_settings.personNameText.isEmpty ? "Empty" : _settings.personNameText, style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                        const SizedBox(width: 8.0),
                        InkWell(
                          onTap: () => _editTextField("Person Name", _settings.personNameText, (val) {
                            setState(() {
                              _settings.personNameText = val;
                              _settings.showPersonName = val.isNotEmpty;
                            });
                          }),
                          child: const Icon(Icons.edit, size: 16.0, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),
                  _buildToggleItem(
                    title: "Weather Status",
                    key: 'weather',
                    value: _settings.showWeather,
                    trailing: const Icon(Icons.wb_sunny, color: Colors.orange, size: 20.0),
                  ),
                  _buildToggleItem(
                    title: "Altitude (Elevation)",
                    key: 'altitude',
                    value: _settings.showAltitude,
                    trailing: const Icon(Icons.terrain, color: Colors.yellowAccent, size: 20.0),
                  ),
                  _buildToggleItem(
                    title: "Digital Compass",
                    key: 'compass',
                    value: _settings.showCompass,
                    trailing: const Icon(Icons.explore, color: Colors.blueAccent, size: 20.0),
                  ),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
