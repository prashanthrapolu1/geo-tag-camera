import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

class ImagePreviewScreen extends StatelessWidget {
  final File imageFile;

  const ImagePreviewScreen({Key? key, required this.imageFile}) : super(key: key);

  Future<void> _sharePhoto(BuildContext context) async {
    try {
      await Share.shareXFiles(
        [XFile(imageFile.path)],
        text: 'Captured with Geo Tag Camera',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share photo: $e")),
        );
      }
    }
  }

  Future<void> _deletePhoto(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121216),
        title: const Text("Delete Photo", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this photo?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Photo deleted.")),
            );
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to delete photo: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Preview", style: TextStyle(color: Colors.white, fontSize: 16.0)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deletePhoto(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: Image.file(imageFile),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Color(0xFF121216),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
              border: Border(
                top: BorderSide(color: Colors.white10),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    path.basename(imageFile.path),
                    style: const TextStyle(color: Colors.white54, fontSize: 12.0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("Camera"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sharePhoto(context),
                          icon: const Icon(Icons.share, color: Colors.black),
                          label: const Text("Share Photo", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB300),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
