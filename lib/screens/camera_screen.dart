import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import '../services/image_processor.dart';
import '../widgets/geotag_overlay.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery_screen.dart';
import 'image_preview_screen.dart';
import '../models/template_settings.dart';
import 'advance_template_screen.dart';
import 'settings_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../providers/settings_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  double? _heading;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 0;
  File? _latestImage;
  final GlobalKey _overlayKey = GlobalKey();
  
  TemplateSettings _templateSettings = TemplateSettings();
  bool _isVideoMode = false;
  bool _isRecording = false;

  Future<void> _loadLatestImage() async {
    if (kIsWeb) return;
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String galleryPath = path.join(appDocDir.path, 'geotag_gallery');
      final Directory galleryDir = Directory(galleryPath);

      if (await galleryDir.exists()) {
        final List<FileSystemEntity> entities = galleryDir.listSync();
        final List<File> files = entities
            .whereType<File>()
            .where((file) => file.path.endsWith('.jpg') || file.path.endsWith('.jpeg'))
            .toList();

        if (files.isNotEmpty) {
          // Sort files by last modified date (newest first)
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          setState(() {
            _latestImage = files.first;
          });
          return;
        }
      }
      setState(() {
        _latestImage = null;
      });
    } catch (e) {
      print("Error loading latest image: $e");
    }
  }

  // Geotag Data
  String _address = "Mountainside Lane, Schroon Lake, New York 12870, United States";
  double _latitude = 22.430930;
  double _longitude = 74.405493;
  double _altitude = 0.0;
  String _dateTimeStr = "";
  
  // Weather Mock Details (Configurable via sidebar)
  String _temperature = "39";
  String _humidity = "3";
  String _wind = "32";
  String _pressure = "23";

  // Configuration
  String _activeTemplate = 'default';
  String _activeFilterPreset = 'default';
  bool _isProcessing = false;
  bool _isLocationOverridden = false;
  Timer? _dateTimeTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Controllers for Sidebar Mocking
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _windController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplateSettings();
    _initDateTime();
    _initCamera();
    _initLocation();
    _loadLatestImage();

    FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });

    // Populate Sidebar Controllers
    _addressController.text = _address;
    _latController.text = _latitude.toString();
    _lngController.text = _longitude.toString();
    _tempController.text = _temperature;
    _humidityController.text = _humidity;
    _windController.text = _wind;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _cameraController?.dispose();
    _dateTimeTimer?.cancel();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _tempController.dispose();
    _humidityController.dispose();
    _windController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('template_settings');
      if (jsonStr != null && mounted) {
        setState(() {
          _templateSettings = TemplateSettings.fromJson(json.decode(jsonStr));
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  Future<void> _saveTemplateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('template_settings', json.encode(_templateSettings.toJson()));
    } catch (e) {
      print("Error saving settings: $e");
    }
  }

  void _initDateTime() {
    _updateDateTimeString();
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateDateTimeString();
        });
      }
    });
  }

  void _updateDateTimeString() {
    final DateTime now = DateTime.now();
    final String weekdayStr = DateFormat('EEEE').format(now);
    final String dateStr = DateFormat('dd/MM/yyyy').format(now);
    final String timeStr = DateFormat('hh:mm a').format(now);
    final String timeZone = "GMT ${now.timeZoneOffset.isNegative ? '-' : '+'}${now.timeZoneOffset.inHours.toString().padLeft(2, '0')}:${(now.timeZoneOffset.inMinutes.remainder(60)).toString().padLeft(2, '0')}";
    _dateTimeStr = "$weekdayStr, $dateStr $timeStr $timeZone";
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Look for the first back camera (which is the real/main camera)
        final backCameraIndex = _cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
        );
        _selectedCameraIndex = backCameraIndex != -1 ? backCameraIndex : 0;
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      } else {
        _showSnackBar("No cameras available on this device.");
      }
    } catch (e) {
      print("Camera init error: $e");
      _showSnackBar("Failed to load camera stream. Using interactive demo mode.");
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print("Camera controller initialize error: $e");
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Start streaming real-time location updates immediately as user moves
        _startLocationStream();

        try {
          // Get immediate current position with isolation
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 4),
            ),
          );
          _updatePositionState(position);
        } catch (e) {
          print("Initial position fetch error: $e");
        }
      }
    } catch (e) {
      print("Location fetch error: $e");
    }
  }

  DateTime? _lastWeatherFetchTime;

  Future<void> _fetchRealWeather(double lat, double lng) async {
    // Throttle weather updates to at most once per 20 seconds to prevent API abuse
    final now = DateTime.now();
    if (_lastWeatherFetchTime != null && now.difference(_lastWeatherFetchTime!) < const Duration(seconds: 20)) {
      return;
    }
    _lastWeatherFetchTime = now;

    try {
      final client = HttpClient();
      final uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,wind_speed_10m,surface_pressure"
      );
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final data = json.decode(content);
        final current = data['current'];
        if (current != null && mounted) {
          setState(() {
            _temperature = (current['temperature_2m'] ?? _temperature).toString();
            _humidity = (current['relative_humidity_2m'] ?? _humidity).toString();
            _wind = (current['wind_speed_10m'] ?? _wind).toString();
            
            final double? pressVal = current['surface_pressure']?.toDouble();
            if (pressVal != null) {
              _pressure = (pressVal / 10).toStringAsFixed(1);
            }

            _tempController.text = _temperature;
            _humidityController.text = _humidity;
            _windController.text = _wind;
          });
        }
      }
    } catch (e) {
      print("Error fetching real weather: $e");
    }
  }

  void _updatePositionState(Position position) async {
    if (!mounted || _isLocationOverridden) return;

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _altitude = position.altitude;
      _latController.text = _latitude.toString();
      _lngController.text = _longitude.toString();
    });

    // Fetch real weather from internet
    _fetchRealWeather(position.latitude, position.longitude);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted && !_isLocationOverridden) {
        Placemark place = placemarks.first;
        
        String flag = "";
        if (place.isoCountryCode != null && place.isoCountryCode!.length == 2) {
          flag = " " + place.isoCountryCode!.toUpperCase().replaceAllMapped(RegExp(r'[A-Z]'),
              (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397));
        }

        String addr = "${place.name}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}, ${place.country}$flag";
        setState(() {
          _address = addr;
          _addressController.text = addr;
        });
      }
    } catch (e) {
      print("Geocoding fetch error: $e");
    }
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0, // Update continuously as the user moves in any direction
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _updatePositionState(position);
    });
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) {
      _showSnackBar("Only one camera available.");
      return;
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitialized = false;
    });
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Utilizing real-time location stream coordinates directly without awaiting GPS check on every capture.
      // This eliminates the 5+ second capture delay.

      String imagePath;
      final XFile rawPhoto;

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        // Real Capture
        rawPhoto = await _cameraController!.takePicture();
        imagePath = rawPhoto.path;
      } else {
        // Fallback: Simulator mode - create a simple dummy image
        _showSnackBar("Simulator mode: Capturing virtual photo...");
        // In virtual mode, we don't have a real camera file, so we'll mock it.
        // For standard offline debugs, we can construct or fetch a placeholder image bytes,
        // but let's throw an error or handle it gracefully. We want to be robust:
        _showSnackBar("Failed to capture: Camera not initialized.");
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Capture the exact UI of the overlay
      RenderRepaintBoundary? boundary = _overlayKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      Uint8List? overlayBytes;
      if (boundary != null) {
        ui.Image uiImage = await boundary.toImage(pixelRatio: 3.0); // 3x scale for crispness
        ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          overlayBytes = byteData.buffer.asUint8List();
        }
      }

      // Process image using ImageProcessor (adding watermark & filters)
      final Uint8List imageBytes = await rawPhoto.readAsBytes();
      final String outputPath = await ImageProcessor.processAndSaveImage(
        inputPath: imagePath,
        imageBytes: imageBytes,
        overlayBytes: overlayBytes,
        address: _address,
        latitude: _latitude,
        longitude: _longitude,
        altitude: _altitude,
        heading: _heading,
        dateTimeStr: _dateTimeStr,
        temperature: _temperature,
        humidity: _humidity,
        wind: _wind,
        pressure: _pressure,
        template: _activeTemplate,
        filterPreset: _activeFilterPreset,
        settings: _templateSettings,
        appSettings: ref.read(appSettingsProvider),
      );

      _showSnackBar("Captured! Photo saved.");
      
      // Clear temporary taken picture
      if (!kIsWeb) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }

      await _loadLatestImage();

      if (mounted && outputPath != "web_captured_image") {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(imageFile: File(outputPath)),
          ),
        );
        _loadLatestImage();
      }

    } catch (e) {
      print("Capture error: $e");
      _showSnackBar("Capture failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isRecordingVideo) return;
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      _showSnackBar("Failed to start recording: $e");
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) return;
    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      _showSnackBar("Saving video...");
      
      if (!kIsWeb) {
        await Gal.putVideo(video.path);
        _showSnackBar("Video saved to gallery!");
      }
      
    } catch (e) {
      _showSnackBar("Failed to stop recording: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Visual filter color matrix generator based on selected preset
  ColorFilter _getColorFilter(String preset) {
    switch (preset) {
      case 'chrome':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, -10,
          0, 1.2, 0, 0, -10,
          0, 0, 1.2, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'vintage':
        return const ColorFilter.matrix([
          0.94, 0.38, 0.18, 0, 0,
          0.3, 0.8, 0.16, 0, 0,
          0.15, 0.2, 0.5, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'mono':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'warm':
        return const ColorFilter.matrix([
          1.1, 0, 0, 0, 5,
          0, 1.0, 0, 0, 0,
          0, 0, 0.9, 0, -5,
          0, 0, 0, 1, 0,
        ]);
      case 'cool':
        return const ColorFilter.matrix([
          0.9, 0, 0, 0, -5,
          0, 1.0, 0, 0, 0,
          0, 0, 1.1, 0, 5,
          0, 0, 0, 1, 0,
        ]);
      case 'default':
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Row(
        children: [
          // 1. Sidebar (Options & Settings) - Shown on desktop/tablet/web
          if (MediaQuery.of(context).size.width > 900)
            _buildSidebar(),

          // 2. Camera viewport panel
          Expanded(
            child: _buildCameraViewport(),
          ),
        ],
      ),
      // Drawer layout fallback for smaller screens
      drawer: MediaQuery.of(context).size.width <= 900 ? Drawer(child: _buildSidebar()) : null,
    );
  }

  // Sidebar controls
  Widget _buildSidebar() {
    return Container(
      width: 340.0,
      decoration: const BoxDecoration(
        color: Color(0xFF121216),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Color(0xFFFFB300)),
                  const SizedBox(width: 10.0),
                  const Text(
                    "GEO CAMERA",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (MediaQuery.of(context).size.width <= 900) ...[
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  ]
                ],
              ),
              const Divider(color: Colors.white10, height: 32.0),

              // Location settings
              _buildSectionTitle("GEOTAG OVERRIDES"),
              const SizedBox(height: 12.0),
              TextField(
                controller: _addressController,
                enabled: false,
                style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                maxLines: 2,
                decoration: _getTextFieldDecoration("Address Location"),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      enabled: false,
                      style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                      keyboardType: TextInputType.number,
                      decoration: _getTextFieldDecoration("Latitude"),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      enabled: false,
                      style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                      keyboardType: TextInputType.number,
                      decoration: _getTextFieldDecoration("Longitude"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLocationOverridden = false;
                  });
                  _initLocation();
                },
                icon: const Icon(Icons.my_location, size: 16.0),
                label: const Text("Fetch GPS Location", style: TextStyle(fontSize: 12.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 36.0),
                ),
              ),

              const Divider(color: Colors.white10, height: 32.0),

              // Weather Settings
              _buildSectionTitle("WEATHER STATS"),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tempController,
                      enabled: false,
                      style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                      decoration: _getTextFieldDecoration("Temp (°C)"),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: TextField(
                      controller: _humidityController,
                      enabled: false,
                      style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                      decoration: _getTextFieldDecoration("Humidity (%)"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _windController,
                      enabled: false,
                      style: const TextStyle(color: Colors.white54, fontSize: 13.0),
                      decoration: _getTextFieldDecoration("Wind (km/h)"),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF1E1E24),
                          value: _activeTemplate,
                          items: const [
                            DropdownMenuItem(value: 'default', child: Text("Default Card", style: TextStyle(color: Colors.white, fontSize: 12.0))),
                            DropdownMenuItem(value: 'modern', child: Text("Modern Accent", style: TextStyle(color: Colors.white, fontSize: 12.0))),
                            DropdownMenuItem(value: 'minimal', child: Text("Minimal Bottom", style: TextStyle(color: Colors.white, fontSize: 12.0))),
                            DropdownMenuItem(value: 'sidebar-style', child: Text("Top-Right Box", style: TextStyle(color: Colors.white, fontSize: 12.0))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _activeTemplate = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(color: Colors.white10, height: 32.0),

              // Filter Presets Selection
              _buildSectionTitle("FILTER EFFECTS"),
              const SizedBox(height: 12.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _buildFilterPresetBtn("Normal", "default"),
                  _buildFilterPresetBtn("Chrome", "chrome"),
                  _buildFilterPresetBtn("Vintage", "vintage"),
                  _buildFilterPresetBtn("Mono", "mono"),
                  _buildFilterPresetBtn("Warm", "warm"),
                  _buildFilterPresetBtn("Cool", "cool"),
                ],
              ),

              const Divider(color: Colors.white10, height: 32.0),

              // Go to Gallery
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GalleryScreen()),
                  ).then((_) => _loadLatestImage());
                },
                icon: const Icon(Icons.photo_library),
                label: const Text("Open Gallery Collection"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44.0),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              const SizedBox(height: 12.0),
              // Go to Settings
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text("App Settings & Export"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44.0),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Go to Advanced Template Settings
  void _openAdvanceTemplateScreen() async {
    final updatedSettings = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvanceTemplateScreen(
          initialSettings: _templateSettings,
          address: _address,
          latitude: _latitude,
          longitude: _longitude,
          dateTimeStr: _dateTimeStr,
          temperature: _temperature,
          humidity: _humidity,
          wind: _wind,
          pressure: _pressure,
        ),
      ),
    );
    if (updatedSettings != null && updatedSettings is TemplateSettings) {
      setState(() {
        _templateSettings = updatedSettings;
      });
      _saveTemplateSettings();
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }

  InputDecoration _getTextFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 11.0),
      fillColor: const Color(0xFF16161C),
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Color(0xFFFFB300)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    );
  }

  Widget _buildFilterPresetBtn(String label, String preset) {
    final bool isActive = _activeFilterPreset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.0,
          color: isActive ? Colors.black : Colors.white,
        ),
      ),
      selected: isActive,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeFilterPreset = preset;
          });
        }
      },
      selectedColor: const Color(0xFFFFB300),
      backgroundColor: Colors.white10,
    );
  }

  // Camera main view panel
  Widget _buildCameraViewport() {
    final appSettings = ref.watch(appSettingsProvider);
    return Column(
      children: [
        // HUD header bar (smaller screens only)
        if (MediaQuery.of(context).size.width <= 900)
          AppBar(
            backgroundColor: const Color(0xFF0A0A0C),
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const Text("Geo Tag Camera", style: TextStyle(color: Colors.white, fontSize: 16.0)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GalleryScreen()),
                  ).then((_) => _loadLatestImage());
                },
              )
            ],
          ),

        // Live camera view container
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Camera Feed
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: _getColorFilter(_activeFilterPreset),
                    child: _isCameraInitialized && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : _buildCameraFallbackStream(),
                  ),
                ),

                // Focus bracket overlay
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 80.0,
                    height: 80.0,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38, width: 1.0),
                    ),
                  ),
                ),

                // Geotag Watermark Card overlay
                Positioned(
                  bottom: 16.0,
                  left: 16.0,
                  right: 16.0,
                  child: RepaintBoundary(
                    key: _overlayKey,
                    child: GeotagOverlay(
                      address: _address,
                      latitude: _latitude,
                      longitude: _longitude,
                      altitude: _altitude,
                      heading: _heading,
                      dateTimeStr: _dateTimeStr,
                      temperature: _temperature,
                      humidity: _humidity,
                      wind: _wind,
                      pressure: _pressure,
                      template: _activeTemplate,
                      settings: _templateSettings,
                      appSettings: appSettings,
                    ),
                  ),
                ),

                // Loading/processing overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFFB300)),
                        SizedBox(height: 12.0),
                        Text("Watermarking & Saving...", style: TextStyle(color: Colors.white, fontSize: 12.0)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom Shutter Controls bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          color: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo / Video Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isVideoMode = false),
                    child: Text(
                      "PHOTO",
                      style: TextStyle(
                        color: !_isVideoMode ? const Color(0xFFFFB300) : Colors.white54,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24.0),
                  GestureDetector(
                    onTap: () => setState(() => _isVideoMode = true),
                    child: Text(
                      "VIDEO",
                      style: TextStyle(
                        color: _isVideoMode ? const Color(0xFFFFB300) : Colors.white54,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Collection Thumbnail
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GalleryScreen()),
                      ).then((_) => _loadLatestImage());
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44.0,
                          height: 44.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                            color: Colors.white10,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _latestImage != null
                              ? Image.file(
                                  _latestImage!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.photo_library, color: Colors.white70, size: 18.0),
                        ),
                        const SizedBox(height: 4.0),
                        const Text(
                          "Collection",
                          style: TextStyle(color: Colors.white54, fontSize: 9.0),
                        ),
                      ],
                    ),
                  ),

                  // Switch Camera button
                  IconButton(
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28.0),
                    onPressed: _toggleCamera,
                  ),

                  // Capture shutter button
                  GestureDetector(
                    onTap: () {
                      if (_isVideoMode) {
                        if (_isRecording) {
                          _stopVideoRecording();
                        } else {
                          _startVideoRecording();
                        }
                      } else {
                        _capturePhoto();
                      }
                    },
                    child: Container(
                      width: 72.0,
                      height: 72.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4.0),
                      ),
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isVideoMode
                              ? (_isRecording ? Colors.red : Colors.redAccent)
                              : Colors.white,
                          shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: _isRecording ? BorderRadius.circular(8.0) : null,
                        ),
                      ),
                    ),
                  ),

                  // Advance Template Settings Screen
                  IconButton(
                    icon: const Icon(Icons.style, color: Colors.white, size: 28.0),
                    onPressed: _openAdvanceTemplateScreen,
                  ),
                  
                  // Empty placeholder for symmetry
                  const SizedBox(width: 44.0),
                ],
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ],
    );
  }

  // Simulated Camera Stream when running in environments without camera (e.g. desktop web/simulator)
  Widget _buildCameraFallbackStream() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background placeholder graphic
          Opacity(
            opacity: 0.15,
            child: Image.network(
              "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80",
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, color: Colors.white24, size: 48.0),
              SizedBox(height: 8.0),
              Text(
                "CAMERA EMULATOR",
                style: TextStyle(color: Colors.white30, fontSize: 11.0, letterSpacing: 1.5, fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}
