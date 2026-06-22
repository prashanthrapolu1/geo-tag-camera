import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _photoFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGalleryPhotos();
  }

  Future<void> _loadGalleryPhotos() async {
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
        _photoFiles = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

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

        // Sort files by last modified date (newest first)
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _photoFiles = files;
        });
      }
    } catch (e) {
      print("Error loading gallery photos: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo deleted successfully.")),
        );
        _loadGalleryPhotos();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete photo: $e")),
      );
    }
  }

  Future<void> _deleteAllPhotos() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text("Delete All Photos", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete all photos in the gallery? This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete All", style: TextStyle(color: Colors.redAccent)),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              setState(() {
                _isLoading = true;
              });
              try {
                for (final file in _photoFiles) {
                  if (await file.exists()) {
                    await file.delete();
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All photos deleted successfully.")),
                );
                _loadGalleryPhotos();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to delete some photos: $e")),
                );
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(int initialIndex) {
    int currentIndex = initialIndex;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: StatefulBuilder(
            builder: (context, setStateSB) {
              return Stack(
                children: [
                  PageView.builder(
                    itemCount: _photoFiles.length,
                    controller: PageController(initialPage: initialIndex),
                    itemBuilder: (context, index) {
                      final file = _photoFiles[index];
                      return Center(
                        child: InteractiveViewer(
                          child: Image.file(file),
                        ),
                      );
                    },
                    onPageChanged: (index) {
                      setStateSB(() {
                        currentIndex = index;
                      });
                    },
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () {
                                final file = _photoFiles[currentIndex];
                                Share.shareXFiles([XFile(file.path)], text: 'Geotagged Photo');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                final file = _photoFiles[currentIndex];
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E24),
                                    title: const Text("Delete Photo", style: TextStyle(color: Colors.white)),
                                    content: const Text("Are you sure you want to delete this geotagged photo?", style: TextStyle(color: Colors.white70)),
                                    actions: [
                                      TextButton(
                                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      TextButton(
                                        child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                                        onPressed: () {
                                          Navigator.pop(context); // Close dialog
                                          Navigator.pop(context); // Close viewer
                                          _deletePhoto(file);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121216),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Gallery Collection", style: TextStyle(color: Colors.white, fontSize: 16.0)),
        elevation: 0,
        actions: [
          if (_photoFiles.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: _deleteAllPhotos,
              tooltip: "Delete All",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)))
          : _photoFiles.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                    childAspectRatio: 9 / 16,
                  ),
                  itemCount: _photoFiles.length,
                  itemBuilder: (context, index) {
                    final File file = _photoFiles[index];
                    return GestureDetector(
                      onTap: () => _openFullScreenImage(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.white10),
                          color: const Color(0xFF1E1E24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              file,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black87, Colors.transparent],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  path.basename(file.path),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 8.0),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64.0, color: Colors.white24),
          const SizedBox(height: 16.0),
          Text(
            kIsWeb ? "Gallery is not supported on Web" : "Your Geotag collection is empty",
            style: const TextStyle(color: Colors.white54, fontSize: 14.0),
          ),
          const SizedBox(height: 8.0),
          Text(
            kIsWeb ? "Use a mobile device to save and view photos" : "Captured photos with watermarks will appear here",
            style: const TextStyle(color: Colors.white30, fontSize: 11.0),
          ),
        ],
      ),
    );
  }
}
