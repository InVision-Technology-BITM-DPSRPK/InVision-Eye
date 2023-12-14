import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class CamScreen extends StatefulWidget {
  @override
  _CamScreenState createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
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

      final String response = await sendImg(path);
      //_speakText(clarifaiResponse.objects[0].data.concepts.name[0]);
      final Map<String, dynamic> jsonData = jsonDecode(response);
      List<String> objectTypes = List.from(jsonData['Objects']
          .where((obj) => obj['Probabilty'] > 0.70)
          .map((obj) => obj['Object_type'])
          .cast<String>());
      for (String objectType in objectTypes) {
        _speakText(objectType);
      }

      await File(path).delete();
    } catch (e) {
      _speakText('Error taking photo: $e');
    }
  }

  Future<String> sendImg(String imgPath) async {
    try {
      final apiUrl = 'http://122.163.105.89:5000/predict';

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('image', imgPath));

      var response = await request.send();

      if (response.statusCode == 200) {
        return utf8.decode(await response.stream.toBytes());
      } else {
        _speakText('${response.statusCode}');

        throw Exception('Image upload failed');
      }
    } catch (e) {
      _speakText('Error uploading image: $e');

      throw Exception('Image upload failed');
    }
  }

  void _startAutoCapture() {
    _timer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      _takeAndSavePhoto();
    });
  }

  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
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
      appBar: AppBar(
        title: Text('InvisEye'),
      ),
      body: GestureDetector(
        onTap: () {
          _takeAndSavePhoto();
        },
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: CameraPreview(_controller),
        ),
      ),
    );
  }
}
