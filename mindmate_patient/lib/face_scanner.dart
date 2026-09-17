import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mindmate_patient/api_config.dart';
import 'package:mindmate_patient/main.dart';

class FaceScannerScreen extends StatefulWidget {
  const FaceScannerScreen({super.key});

  @override
  State<FaceScannerScreen> createState() => _FaceScannerScreenState();
}

class _FaceScannerScreenState extends State<FaceScannerScreen> {
  CameraController? _controller;
  bool _isBusy = false;
  late List<CameraDescription> _cameras;
  int _currentCameraIndex = 0;
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );

  final FlutterTts _flutterTts = FlutterTts();
  String _statusText = "Align face in frame";
  bool _isIdentifying = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    
    if (_cameras.isEmpty) {
      debugPrint("No cameras available");
      return;
    }
    
    // Start with front camera if available, otherwise use first camera
    _currentCameraIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (_currentCameraIndex == -1) {
      _currentCameraIndex = 0;
    }

    await _initCameraController();
  }

  Future<void> _initCameraController() async {
    if (_cameras.isEmpty || _currentCameraIndex >= _cameras.length) return;
    
    _controller?.dispose();
    
    _controller = CameraController(
      _cameras[_currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller?.initialize();
    if (!mounted) return;
    setState(() {});

    _controller?.startImageStream(_processCameraImage);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      debugPrint("Only one camera available");
      return;
    }
    
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initCameraController();
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || _isIdentifying) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty && !_isIdentifying) {
        // A face is in frame! Let's pause and identify.
        _identifyFace();
      }
    } catch (e) {
      debugPrint("Processing error: $e");
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final sensorOrientation = _controller!.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (_controller!.description.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> _identifyFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isIdentifying = true;
      _statusText = "Identifying...";
    });

    try {
      final XFile file = await _controller!.takePicture();

      // CALL AI MICROSERVICE
      final uri = Uri.parse(ApiConfig.aiServiceUrl); 
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', file.path));

      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("User not logged in");
        return;
      }
      request.fields['patient_id'] = user.id;

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = json.decode(responseBody.body);
        if (data['match_found'] == true && data['person_id'] != null) {
          final matchedPersonId = data['person_id'];

          // Fetch person details from Supabase
          final personData = await supabase
              .from('tbl_known_person')
              .select('name, relation, voice_prompt_message')
              .eq('id', matchedPersonId)
              .maybeSingle();

          if (personData != null) {
            final String name = personData['name'] ?? "Unknown";
            final String relation = personData['relation'] ?? "";
            final String? audioUrl = personData['voice_prompt_message'];

            String speechMessage = "This is $name, your $relation.";
            setState(() => _statusText = speechMessage);
            
            // Log this encounter
            logActivity("Face Identified", "Recognized person: $name ($relation)");
            
            // Play TTS Message
            await _flutterTts.speak(speechMessage);

            // Play recorded audio if available
            if (audioUrl != null && audioUrl.isNotEmpty) {
              try {
                final AudioPlayer audioPlayer = AudioPlayer();
                await audioPlayer.play(UrlSource(audioUrl));
              } catch (e) {
                debugPrint("Audio Playback Error: $e");
              }
            }
          } else {
            setState(() => _statusText = "Match Found, but record missing.");
          }
        } else {
          setState(() => _statusText = "Unknown Person");
          await _flutterTts.speak("I don't recognize this person.");
        }
      } else {
        setState(() => _statusText = "Recognition Service Offline");
      }
    } catch (e) {
      debugPrint("Identification error: $e");
      setState(() => _statusText = "Check Connection");
    } finally {
      // COOL-DOWN PERIOD
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isIdentifying = false;
          _statusText = "Align face in frame";
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // Overlay
          IgnorePointer(
            child: Container(
              decoration: ShapeDecoration(
                shape: FaceDetectionOverlayShape(
                  borderColor: _isIdentifying ? Colors.teal : Colors.white,
                  borderWidth: 4,
                  radius: 50,
                ),
              ),
            ),
          ),

          // Header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  "FACE IDENTIFY",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),

          // Status & Button
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _isIdentifying ? null : _identifyFace,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isIdentifying ? Colors.teal : Colors.transparent,
                    ),
                    child: Center(
                      child: Container(
                        height: 60,
                        width: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
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
}

class FaceDetectionOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double radius;

  const FaceDetectionOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.radius = 20.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Path path = Path()..addRect(rect);
    final double size = rect.width * 0.7;
    final Rect faceRect = Rect.fromCenter(
      center: rect.center,
      width: size,
      height: size * 1.2,
    );
    path.addRRect(RRect.fromRectAndRadius(faceRect, Radius.circular(radius)));
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final double size = rect.width * 0.7;
    final Rect faceRect = Rect.fromCenter(
      center: rect.center,
      width: size,
      height: size * 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  ShapeBorder scale(double t) => FaceDetectionOverlayShape(
    borderColor: borderColor,
    borderWidth: borderWidth * t,
    radius: radius * t,
  );
}
