import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        title: const Text("App Settings", style: TextStyle(color: Colors.white, fontSize: 16.0)),
        backgroundColor: const Color(0xFF121216),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader("LOCATION FORMAT"),
          SwitchListTile(
            title: const Text("Use DMS Format", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Display coordinates as Degrees, Minutes, Seconds", style: TextStyle(color: Colors.white54)),
            activeColor: const Color(0xFFFFB300),
            value: settings.useDMSFormat,
            onChanged: (val) => notifier.setUseDMSFormat(val),
          ),
          const Divider(color: Colors.white10),
          _buildSectionHeader("WEATHER UNITS"),
          SwitchListTile(
            title: const Text("Use Fahrenheit (°F)", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Display temperature in Fahrenheit instead of Celsius", style: TextStyle(color: Colors.white54)),
            activeColor: const Color(0xFFFFB300),
            value: settings.useFahrenheit,
            onChanged: (val) => notifier.setUseFahrenheit(val),
          ),
          const Divider(color: Colors.white10),
          _buildSectionHeader("DATE FORMAT"),
          ListTile(
            title: const Text("Date Display Format", style: TextStyle(color: Colors.white)),
            subtitle: Text(settings.dateFormat, style: const TextStyle(color: Colors.white54)),
            trailing: DropdownButton<String>(
              dropdownColor: const Color(0xFF1E1E24),
              value: settings.dateFormat,
              items: const [
                DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('dd/MM/yyyy', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/dd/yyyy', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) {
                if (val != null) notifier.setDateFormat(val);
              },
            ),
          ),
          const Divider(color: Colors.white10),
          _buildSectionHeader("EXPORT"),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.white54),
            title: const Text("Export PDF Report", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Generate a PDF report of captured photos", style: TextStyle(color: Colors.white54)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("PDF Export requires Gallery Phase integration.")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.data_object, color: Colors.white54),
            title: const Text("Export JSON Data", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Export metadata for all captured photos", style: TextStyle(color: Colors.white54)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("JSON Export requires Gallery Phase integration.")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFB300),
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
