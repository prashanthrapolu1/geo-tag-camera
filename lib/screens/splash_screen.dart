import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Show splash for exactly 3 seconds
    final splashTimer = Future.delayed(const Duration(seconds: 3));

    // Request permissions
    final statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    // If location granted, fetch location in background to warm up GPS
    if (statuses[Permission.location]?.isGranted ?? false) {
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 2), // Don't let this block for more than 2s just in case
        ),
      ).catchError((_) => null); // Ignore errors, this is just a warm up
    }

    await splashTimer;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              'assets/icon.png',
              width: 200.0,
              height: 200.0,
            ),
            const SizedBox(height: 24.0),
            
            // App Name
            const Text(
              "Geo Tag Camera Nandu",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 40.0),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
            ),
          ],
        ),
      ),
    );
  }
}
