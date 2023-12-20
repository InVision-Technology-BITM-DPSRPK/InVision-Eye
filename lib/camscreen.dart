import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

class CamScreen extends StatefulWidget {
  @override
  _CamScreenState createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  final myController = TextEditingController();
  late List<CameraDescription> cameras = [];
  late CameraController _controller;
  late Timer _timer;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initCamController();
    _configureTts();
    _startAutoCapture();
  }

  void _initCamController() async {
    WidgetsFlutterBinding.ensureInitialized();
    var status = await Permission.camera.request();
    if (status.isGranted) {
      cameras = await availableCameras();
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
       

      _controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    } else {
      _speakText("Camera Permission Denied");
    }
  }

  Future<void> _configureTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setPitch(1.0);
    await flutterTts.setVolume(1.0);
  }

  Future<void> _takeAndSavePhoto() async {
    try {
      if (!_controller.value.isInitialized) {
        return;
      }
      
      final XFile photo = await _controller.takePicture();
      final String path = join(
        (await getTemporaryDirectory()).path,
        'img.jpg',
      );
      await File(photo.path).copy(path);
      final String temp = 'http://${myController.text}:5000/predict';
      print("@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#@#$temp");
      final String response = await sendImg(path, temp);

      print(response);

      final Map<String, dynamic> jsonData = await jsonDecode(response);

      if (jsonData.containsKey('Objects') && jsonData['Objects'] is List) {
        List<String> objectTypes = [];

        for (var obj in jsonData['Objects']) {
          try {
            if (obj is Map<String, dynamic> &&
                obj.containsKey('Probabilty') &&
                obj['Probabilty'] != null &&
                obj['Probabilty'] is num &&
                obj.containsKey('Object_type') &&
                obj['Object_type'] != null &&
                obj['Object_type'] is String &&
                obj['Probabilty'] > 0.45) {
              objectTypes.add(obj['Object_type']);
            }
          } catch (e) {
            _speakText("Error in processing object: $e");
          }
        }

        if (objectTypes.isEmpty) {
          _speakText("No objects found");
        } else {
          for (String objectType in objectTypes) {
            print(
                "$objectType $objectType $objectType $objectType $objectType $objectType $objectType $objectType");
            await _speakText("$objectType");
          }
        }
      } else {
        _speakText("No objects found");
      }
    } catch (e, stacktrace) {
      //_speakText('Error taking photo: $e');
      print(
          '######################################################Stacktrace: $stacktrace');
    }
  }
  Future<void> resizeImage(String imagePath, int width, int height) async {
  try {
    File imageFile = File(imagePath);
    List<int> imageBytes = imageFile.readAsBytesSync();
    img.Image? originalImage = img.decodeImage(Uint8List.fromList(imageBytes));
    if (originalImage != null) {
      final String resizedPath = join(
        (await getTemporaryDirectory()).path,
        'img2.jpg',
      );

      // Resize the image
      img.Image resizedImage = img.copyResize(originalImage, width: 640, height: 640);

      // Save the resized image
      File(resizedPath).writeAsBytesSync(img.encodeJpg(resizedImage));

      // Delete the original image
      await imageFile.delete();
    } else {
      print('Error decoding image: Image is null');
    }
  } catch (e) {
    print('Error resizing image: $e');
  }
}

  Future<String> sendImg(String imgPath, String apiUrl) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('file', imgPath));

      var response = await request.send();

      if (response.statusCode == 200) {
        return utf8.decode(await response.stream.toBytes());
      } else {
        _speakText('${response.statusCode}');

        throw Exception('Image upload failed');
      }
    } catch (e) {
      //_speakText('Error uploading image: $e');

      throw Exception('Image upload failed');
    }
  } 

  void _startAutoCapture() {
    _timer =
        Timer.periodic(const Duration(seconds: 9), (Timer timer) {
      _takeAndSavePhoto();
    });
  }

  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
    await Future.delayed(const Duration(seconds: 1, milliseconds: 700));
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller.value.isInitialized) {
      return Container();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(40.0),
        child: AppBar(
          backgroundColor: Colors.grey[800],
          title: Text('InvisEye', style: TextStyle(fontSize: 16)),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _takeAndSavePhoto();
                    },
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: CameraPreview(_controller),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _takeAndSavePhoto();
                    },
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: CameraPreview(_controller),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter IP Address',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
              ),
              style: TextStyle(color: Colors.white),
              controller: myController,
            ),
          ),
        ],
      ),
    );
  }
}
