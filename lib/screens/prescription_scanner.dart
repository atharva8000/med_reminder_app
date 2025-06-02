// [IMPORTS]
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:path/path.dart' as path; // Import the path package

import 'medicine_options.dart';
import 'medicine_history.dart';
import 'user_profile.dart';
import 'medicine_reminder.dart';
import 'shop_lists.dart';

class PrescriptionScanner extends StatefulWidget {
  const PrescriptionScanner({super.key});

  @override
  State<PrescriptionScanner> createState() => _PrescriptionScannerState();
}

class _PrescriptionScannerState extends State<PrescriptionScanner> {
  File? _image;
  List<String> _medicineNames = []; // Changed to a list of medicine names
  bool _isProcessing = false;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  final picker = ImagePicker();

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      if (!mounted) return;
      setState(() {
        _isProcessing = true;
        _secondsRemaining = 60;
        _medicineNames = []; // Clear previous medicine names
      });

      _startCountdown();

      File file = File(pickedFile.path);

      if (!mounted) return;
      setState(() {
        _image = file; // Set the original file
      });

      String mimeType = '';
      final extension = path.extension(file.path).toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == '.png') {
        mimeType = 'image/png';
      } else {
        mimeType = 'image/jpeg';
        print('Warning: Unknown image extension: $extension. Defaulting to image/jpeg.');
      }
      print('Detected MIME Type: $mimeType');

      await _sendToBackendForPrediction(file, mimeType); // Send the original file
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendToBackendForPrediction(File imageFile, String mimeType) async {
    const flaskApiUrl = 'http://192.xxx.xx.xx:5000/predict'; // Replace with your Flask backend URL
    print('Flask API URL: $flaskApiUrl');
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(flaskApiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'image': base64Image,
          'mimeType': mimeType, // Send the mimeType in the JSON body
        }),
      );
      print('Response Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool success = data['success'] ?? false;
        if (success) {
          final List<String> medicineNames = List<String>.from(data['medicine_names'] ?? []);
          setState(() {
            _medicineNames = medicineNames; // Update the medicine names list
          });
        } else {
          final String errorMessage = data['error'] ?? 'Failed to get prediction.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backend error: $errorMessage'), backgroundColor: Colors.red),
          );
        }
      } else {
        throw Exception('Server responded with status code: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to backend: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _image != null
                  ? Card(
                key: ValueKey(_image),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!),
                    ),
                    if (_isProcessing)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Shimmer.fromColors(
                                  baseColor: Colors.white70,
                                  highlightColor: Colors.grey.shade300,
                                  child: const Text(
                                    'Processing...',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_secondsRemaining seconds remaining',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
                  : const SizedBox(
                height: 200,
                child: Center(child: Text('No image selected.')),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _getImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Picture'),
                ),
                FilledButton.icon(
                  onPressed: () => _getImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_medicineNames.isNotEmpty) ...[
              const Text('Medicine Names:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _medicineNames.map((name) => Text('- $name', style: const TextStyle(fontSize: 14))).toList(),
                ),
              ),
            ],
            const SizedBox(height: 30),
            FilledButton.icon(
              onPressed: _medicineNames.isEmpty
                  ? null
                  : () => _navigateTo(MedicineOptionsScreen(
                  medicineNames: _medicineNames)),
              icon: const Icon(Icons.medication),
              label: const Text('Show Medicine Options'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _navigateTo(const MedicineHistoryScreen()),
              icon: const Icon(Icons.history),
              label: const Text('My Orders'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _navigateTo(const UserProfileScreen()),
              icon: const Icon(Icons.person),
              label: const Text('User Profile'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _navigateTo(const MedicineReminderScreen()),
              icon: const Icon(Icons.alarm),
              label: const Text('Medicine Reminder'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _medicineNames.isEmpty
                  ? null
                  : () => _navigateTo(ShopListScreen(
                  medicineNames: _medicineNames)),
              icon: const Icon(Icons.local_pharmacy),
              label: const Text('Find Nearby Shops'),
            ),
          ],
        ),
      ),
    );
  }
}
