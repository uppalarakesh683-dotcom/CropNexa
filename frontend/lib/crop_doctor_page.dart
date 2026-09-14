
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'current_user_session.dart';

// ============================================================
// API
// ============================================================

const String cropDoctorApiBaseUrl = 'https://cropnexa-backend.onrender.com';

// ============================================================
// 1. CROP DOCTOR HOME
// ============================================================

class CropDoctorPage extends StatefulWidget {
  const CropDoctorPage({super.key});

  @override
  State<CropDoctorPage> createState() => _CropDoctorPageState();
}

class _CropDoctorPageState extends State<CropDoctorPage> {
  final ImagePicker _picker = ImagePicker();

  File? selectedImage;
  String? selectedCrop;

  Future<void> _openImageSource() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropDoctorImageSourcePage(
          onCamera: () async {
            Navigator.pop(context);
            await _openCamera();
          },
          onGallery: () async {
            Navigator.pop(context);
            await _openGallery();
          },
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = File(image.path);
      });

      await _openCropSelection();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open camera: $e'),
        ),
      );
    }
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        selectedImage = File(image.path);
      });

      await _openCropSelection();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open gallery: $e'),
        ),
      );
    }
  }

  Future<void> _openCropSelection() async {
    if (selectedImage == null) return;

    final String? crop = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CropTypeSelectionPage(
          image: selectedImage!,
        ),
      ),
    );

    if (crop == null || !mounted) return;

    setState(() {
      selectedCrop = crop;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          image: selectedImage!,
          cropType: selectedCrop!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'AI Crop Doctor',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123D27),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroSection(),
                    const SizedBox(height: 22),
                    _scanCard(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            icon: Icons.camera_alt_rounded,
                            title: 'Camera',
                            subtitle: 'Capture crop image',
                            onTap: _openCamera,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _actionCard(
                            icon: Icons.photo_library_rounded,
                            title: 'Gallery',
                            subtitle: 'Choose an image',
                            onTap: _openGallery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _historyCard(),
                    const SizedBox(height: 24),
                    _informationCard(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _heroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B5D36),
            Color(0xFF159447),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'AI Crop Doctor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a crop image and get an AI-powered analysis.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFFE1EAE3),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF168348),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Analyze your crop',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF173D28),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Take a clear photo or select one from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openImageSource,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text(
                'Choose Image',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF148446),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE1EAE3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF148446),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173D28),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AnalysisHistoryPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE1EAE3),
          ),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFEAF7EE),
              child: Icon(
                Icons.history_rounded,
                color: Color(0xFF148446),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis History',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF173D28),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'View your saved crop analyses',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _informationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF168348),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'For better analysis, capture a clear image of the affected crop area with good lighting.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF28553A),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 2. CHOOSE IMAGE SOURCE
// ============================================================

class CropDoctorImageSourcePage extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const CropDoctorImageSourcePage({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F5),
      appBar: AppBar(
        title: const Text(
          'Choose Image Source',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'How would you like to add your crop image?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173D28),
              ),
            ),
            const SizedBox(height: 35),
            _sourceButton(
              icon: Icons.camera_alt_rounded,
              title: 'Camera',
              subtitle: 'Capture a new crop image',
              onTap: onCamera,
            ),
            const SizedBox(height: 16),
            _sourceButton(
              icon: Icons.photo_library_rounded,
              title: 'Gallery',
              subtitle: 'Select an existing crop image',
              onTap: onGallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFDDE8DF),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF148446),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF173D28),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 3. CROP TYPE SELECTION
// ============================================================

class CropTypeSelectionPage extends StatefulWidget {
  final File image;

  const CropTypeSelectionPage({
    super.key,
    required this.image,
  });

  @override
  State<CropTypeSelectionPage> createState() =>
      _CropTypeSelectionPageState();
}

class _CropTypeSelectionPageState
    extends State<CropTypeSelectionPage> {
  String? selectedCrop;

  final List<String> crops = const [
    'Chilli',
    'Rice',
    'Maize',
    'Cotton',
    'Tomato',
    'Groundnut',
    'Sugarcane',
    'Paddy',
    'Wheat',
    'Other',
  ];

  void _continue() {
    if (selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the crop type.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      selectedCrop,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Select Crop',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(
                  widget.image,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What crop is this?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173D28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select the crop shown in the image.',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  15,
                ),
                itemCount: crops.length,
                itemBuilder: (context, index) {
                  final crop = crops[index];
                  final bool selected = selectedCrop == crop;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedCrop = crop;
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE4F6E7)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF148446)
                                : const Color(0xFFE1EAE3),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 43,
                              width: 43,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EE),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.grass_rounded,
                                color: Color(0xFF148446),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                crop,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF173D28),
                                ),
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? const Color(0xFF148446)
                                  : Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                4,
                18,
                18,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF148446),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 4. IMAGE PREVIEW
// ============================================================

class ImagePreviewPage extends StatelessWidget {
  final File image;
  final String cropType;

  const ImagePreviewPage({
    super.key,
    required this.image,
    required this.cropType,
  });

  void _startAnalysis(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisProgressPage(
          image: image,
          cropType: cropType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Image Preview',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.file(
                    image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.grass_rounded,
                      color: Color(0xFF148446),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cropType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF173D28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _startAnalysis(context),
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                  ),
                  label: const Text(
                    'Analyze Image',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF148446),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 5. ANALYSIS IN PROGRESS
// ============================================================

class AnalysisProgressPage extends StatefulWidget {
  final File image;
  final String cropType;

  const AnalysisProgressPage({
    super.key,
    required this.image,
    required this.cropType,
  });

  @override
  State<AnalysisProgressPage> createState() =>
      _AnalysisProgressPageState();
}

class _AnalysisProgressPageState
    extends State<AnalysisProgressPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool _analyzing = true;
  String _status = 'Preparing crop image...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _analyzeCrop();
  }

  Future<void> _analyzeCrop() async {
    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      _showError('No logged-in user was found. Please log in again.');
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _status = 'Uploading crop image...';
        });
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$cropDoctorApiBaseUrl/api/crop-doctor/analyze',
        ),
      );

      request.fields['user_id'] = userId.toString();
      request.fields['crop_type'] = widget.cropType;

      final String extension =
          widget.image.path.split('.').last.toLowerCase();

      String mimeType = 'image/jpeg';

      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      } else if (extension == 'heic') {
        mimeType = 'image/heic';
      } else if (extension == 'heif') {
        mimeType = 'image/heif';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          widget.image.path,
          contentType: _parseMediaType(mimeType),
        ),
      );

      if (mounted) {
        setState(() {
          _status = 'AI is examining your crop...';
        });
      }

      final streamedResponse = await request.send();

      final response =
          await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        String errorMessage =
            'Crop Doctor server returned ${response.statusCode}.';

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map &&
              decoded['message'] != null) {
            errorMessage = decoded['message'].toString();
          }
        } catch (_) {}

        _showError(errorMessage);
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['analysis'] == null) {
        _showError(
          'The AI server returned an invalid analysis response.',
        );
        return;
      }

      final Map<String, dynamic> analysis =
          Map<String, dynamic>.from(
        decoded['analysis'] as Map,
      );

      final bool isCropImage =
          analysis['is_crop_image'] != false;

      if (!isCropImage) {
        _showError(
          'The uploaded image does not appear to be a crop image. Please upload a clear crop photo.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _status = 'Analysis completed successfully.';
        _analyzing = false;
      });

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultsPage(
            image: widget.image,
            cropType: widget.cropType,
            analysis: analysis,
          ),
        ),
      );
    } on SocketException {
      _showError(
        'Cannot connect to CropNexa backend.\n\nMake sure Flask is running and your phone and computer are connected to the same network.',
      );
    } on FormatException {
      _showError(
        'The backend returned an invalid response.',
      );
    } catch (e) {
      _showError(
        'Crop Doctor analysis failed.\n\n$e',
      );
    }
  }

  dynamic _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');

    if (parts.length != 2) {
      return null;
    }

    return http.MediaType(
      parts[0],
      parts[1],
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _analyzing = false;
      _status = 'Analysis failed';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crop Doctor Error',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(
                height: 1.45,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F4),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RotationTransition(
                    turns: _controller,
                    child: Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE6F5EA),
                        border: Border.all(
                          color: const Color(0xFF148446),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF148446),
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Analyzing your crop',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF173D28),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (_analyzing)
                    const CircularProgressIndicator(
                      color: Color(0xFF148446),
                    )
                  else
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF148446),
                      size: 44,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 6. ANALYSIS RESULTS
// ============================================================

class AnalysisResultsPage extends StatelessWidget {
  final File image;
  final String cropType;
  final Map<String, dynamic> analysis;

  const AnalysisResultsPage({
    super.key,
    required this.image,
    required this.cropType,
    required this.analysis,
  });

  String _stringValue(
    String key, {
    String fallback = 'Not available',
  }) {
    final value = analysis[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  List<String> _listValue(String key) {
    final value = analysis[key];

    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty) {
        return [];
      }

      return text
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  String _confidenceText() {
    final value = analysis['confidence'];

    if (value == null) {
      return 'Not available';
    }

    if (value is num) {
      final double confidence = value.toDouble();

      if (confidence <= 1) {
        return '${(confidence * 100).toStringAsFixed(0)}%';
      }

      return '${confidence.toStringAsFixed(0)}%';
    }

    return value.toString();
  }

  Color _severityColor() {
    final severity =
        _stringValue(
          'severity',
          fallback: 'unknown',
        ).toLowerCase();

    if (severity == 'high') {
      return Colors.red;
    }

    if (severity == 'moderate') {
      return Colors.orange;
    }

    if (severity == 'low') {
      return Colors.green;
    }

    if (severity == 'healthy') {
      return Colors.green;
    }

    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final symptoms = _listValue('symptoms');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Analysis Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(
              image,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 16),

          _resultCard(
            icon: Icons.grass_rounded,
            title: 'Crop',
            value: cropType,
          ),

          const SizedBox(height: 12),

          _diagnosisCard(),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _smallResultCard(
                  icon: Icons.analytics_rounded,
                  title: 'Confidence',
                  value: _confidenceText(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smallResultCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Severity',
                  value: _stringValue('severity'),
                  valueColor: _severityColor(),
                ),
              ),
            ],
          ),

          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 12),
            _listCard(
              icon: Icons.visibility_rounded,
              title: 'Symptoms Detected',
              items: symptoms,
            ),
          ],

          const SizedBox(height: 18),

          _nextButton(
            context,
            title: 'Treatment & Prevention',
            icon: Icons.medical_services_rounded,
            page: TreatmentPreventionPage(
              cropType: cropType,
              analysis: analysis,
            ),
          ),

          const SizedBox(height: 12),

          _nextButton(
            context,
            title: 'Telugu / English Result',
            icon: Icons.translate_rounded,
            page: TeluguEnglishResultPage(
              cropType: cropType,
              analysis: analysis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFFE1EAE3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF148446),
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'AI Diagnosis',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Color(0xFF173D28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _stringValue('diagnosis'),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF244B35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAF7EE),
            child: Icon(
              icon,
              color: const Color(0xFF148446),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173D28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallResultCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF148446),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: valueColor ??
                  const Color(0xFF173D28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF148446),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173D28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                bottom: 9,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFF148446),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget page,
  }) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => page,
            ),
          );
        },
        icon: Icon(icon),
        label: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF148446),
          side: const BorderSide(
            color: Color(0xFF148446),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 7. TREATMENT & PREVENTION
// ============================================================

class TreatmentPreventionPage extends StatelessWidget {
  final String cropType;
  final Map<String, dynamic> analysis;

  const TreatmentPreventionPage({
    super.key,
    required this.cropType,
    required this.analysis,
  });

  List<String> _listValue(String key) {
    final value = analysis[key];

    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final treatment = _listValue('treatment');
    final prevention = _listValue('prevention');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Treatment & Prevention',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _cropHeader(),

          const SizedBox(height: 14),

          _section(
            icon: Icons.medical_services_rounded,
            title: 'Treatment',
            items: treatment,
            emptyMessage:
                'No treatment recommendation was returned by the AI.',
          ),

          const SizedBox(height: 14),

          _section(
            icon: Icons.shield_rounded,
            title: 'Prevention',
            items: prevention,
            emptyMessage:
                'No prevention recommendation was returned by the AI.',
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Always verify pesticide or chemical treatment recommendations with a qualified agricultural expert before application.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6A4A10),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cropHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.grass_rounded,
              color: Color(0xFF148446),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              cropType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173D28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<String> items,
    required String emptyMessage,
  }) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF148446),
            size: 28,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF173D28),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.5,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF148446),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.45,
                        ),
                      ),
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

// ============================================================
// 8. ANALYSIS HISTORY
// ============================================================

class AnalysisHistoryPage extends StatefulWidget {
  const AnalysisHistoryPage({
    super.key,
  });

  @override
  State<AnalysisHistoryPage> createState() =>
      _AnalysisHistoryPageState();
}

class _AnalysisHistoryPageState
    extends State<AnalysisHistoryPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final int? userId = CurrentUserSession.id;

    if (userId == null) {
      setState(() {
        loading = false;
        error = 'No logged-in user was found.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$cropDoctorApiBaseUrl/api/crop-doctor/history?user_id=$userId',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(
          decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : 'Unable to load analysis history.',
        );
      }

      final dynamic data = decoded['analyses'];

      final List<Map<String, dynamic>> loaded = [];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            loaded.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        history = loaded;
        loading = false;
        error = null;
      });
    } on SocketException {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Unable to connect to CropNexa backend.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _openAnalysis(
    Map<String, dynamic> item,
  ) async {
    final dynamic id = item['id'];

    if (id == null) return;

    final int? userId = CurrentUserSession.id;

    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '$cropDoctorApiBaseUrl/api/crop-doctor/analysis/$id?user_id=$userId',
        ),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Unable to load analysis.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['analysis'] == null) {
        throw Exception(
          'Invalid analysis response.',
        );
      }

      final analysis =
          Map<String, dynamic>.from(
        decoded['analysis'] as Map,
      );

      final String cropType =
          analysis['crop_type']?.toString() ??
              'Crop';

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisDetailsPage(
            analysis: analysis,
            cropType: cropType,
            analysisId: id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open analysis: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Analysis History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
        actions: [
          IconButton(
            onPressed: loading ? null : _loadHistory,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF148446),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 70,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load history',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173D28),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF148446),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 44,
                  color: Color(0xFF148446),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'No analysis history',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173D28),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Your saved Crop Doctor analyses will appear here after you analyze a crop image.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF148446),
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];

          final crop =
              item['crop_type']?.toString() ??
                  item['crop']?.toString() ??
                  'Crop';

          final diagnosis =
              item['diagnosis']?.toString() ??
                  'Analysis available';

          final severity =
              item['severity']?.toString() ??
                  'unknown';

          final createdAt =
              item['created_at']?.toString() ??
                  '';

          return Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: () => _openAnalysis(item),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: const Color(0xFFE1EAE3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EE),
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Color(0xFF148446),
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            crop,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF173D28),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            diagnosis,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Severity: $severity',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF148446),
                            ),
                          ),
                          if (createdAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              createdAt,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// HISTORY DETAIL
// ============================================================

class AnalysisDetailsPage extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final String cropType;
  final dynamic analysisId;

  const AnalysisDetailsPage({
    super.key,
    required this.analysis,
    required this.cropType,
    required this.analysisId,
  });

  @override
  Widget build(BuildContext context) {
    final symptoms = _listValue(
      analysis['symptoms'],
    );

    final treatment = _listValue(
      analysis['treatment'],
    );

    final prevention = _listValue(
      analysis['prevention'],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Saved Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header(
            cropType,
            analysisId,
          ),
          const SizedBox(height: 14),
          _card(
            Icons.health_and_safety_rounded,
            'AI Diagnosis',
            analysis['diagnosis']?.toString() ??
                'Not available',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _card(
                  Icons.analytics_rounded,
                  'Confidence',
                  _confidence(
                    analysis['confidence'],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _card(
                  Icons.warning_amber_rounded,
                  'Severity',
                  analysis['severity']?.toString() ??
                      'Unknown',
                ),
              ),
            ],
          ),
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 12),
            _itemsCard(
              Icons.visibility_rounded,
              'Symptoms',
              symptoms,
            ),
          ],
          if (treatment.isNotEmpty) ...[
            const SizedBox(height: 12),
            _itemsCard(
              Icons.medical_services_rounded,
              'Treatment',
              treatment,
            ),
          ],
          if (prevention.isNotEmpty) ...[
            const SizedBox(height: 12),
            _itemsCard(
              Icons.shield_rounded,
              'Prevention',
              prevention,
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(
    String crop,
    dynamic id,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.grass_rounded,
              color: Color(0xFF148446),
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  crop,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173D28),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analysis #$id',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF148446),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF173D28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(
    IconData icon,
    String title,
    List<String> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF148446),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173D28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(
                bottom: 9,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFF148446),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _confidence(dynamic value) {
    if (value == null) {
      return 'Not available';
    }

    if (value is num) {
      final number = value.toDouble();

      if (number <= 1) {
        return '${(number * 100).toStringAsFixed(0)}%';
      }

      return '${number.toStringAsFixed(0)}%';
    }

    return value.toString();
  }
}

// ============================================================
// 9. TELUGU / ENGLISH RESULT
// ============================================================

class TeluguEnglishResultPage extends StatefulWidget {
  final String cropType;
  final Map<String, dynamic> analysis;

  const TeluguEnglishResultPage({
    super.key,
    required this.cropType,
    required this.analysis,
  });

  @override
  State<TeluguEnglishResultPage> createState() =>
      _TeluguEnglishResultPageState();
}

class _TeluguEnglishResultPageState
    extends State<TeluguEnglishResultPage> {
  bool telugu = false;

  @override
  Widget build(BuildContext context) {
    final String english =
        widget.analysis['english_result']?.toString() ??
            widget.analysis['diagnosis']?.toString() ??
            'No English result available.';

    final String teluguResult =
        widget.analysis['telugu_result']?.toString() ??
            'తెలుగు ఫలితం అందుబాటులో లేదు.';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Result Language',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.translate_rounded,
                  color: Color(0xFF148446),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Result language',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Switch(
                  value: telugu,
                  activeColor: const Color(0xFF148446),
                  onChanged: (value) {
                    setState(() {
                      telugu = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  telugu
                      ? 'తెలుగు ఫలితం'
                      : 'English Result',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173D28),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  telugu
                      ? 'పంట: ${widget.cropType}'
                      : 'Crop: ${widget.cropType}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  telugu ? teluguResult : english,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.55,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 10. CAMERA CAPTURE UI
// ============================================================

class CameraCapturePage extends StatelessWidget {
  const CameraCapturePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white24,
                size: 90,
              ),
            ),
            Positioned(
              top: 15,
              left: 15,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const Positioned(
              top: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Capture Crop Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 35,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 5,
                    ),
                  ),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 11. GALLERY SELECTION UI
// ============================================================

class GallerySelectionPage extends StatelessWidget {
  const GallerySelectionPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text(
          'Gallery',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF173D28),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_rounded,
                size: 75,
                color: Color(0xFF148446),
              ),
              SizedBox(height: 20),
              Text(
                'Select an image',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173D28),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The device gallery picker will provide the real images available on your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

List<String> _listValue(dynamic value) {
  if (value == null) {
    return [];
  }

  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (value is String) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return [];
}
