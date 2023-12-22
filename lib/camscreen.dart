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
  bool flag = true;
  late FlutterTts flutterTts;
  String Speech_temp = "Invision 360 Started0";
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

  _configureTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage('en-US');
    await flutterTts.setPitch(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.awaitSpeakCompletion(true);
    flutterTts.setCompletionHandler(() {});
    
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
      final String path2 = join(
        (await getTemporaryDirectory()).path,
        'img2.jpg',
      );
      await resizeImage(path);
      await File(photo.path).copy(path2);

      final String temp = 'http://${myController.text}:5000/predict';
      final String response = await sendImg(path2, temp);

      final Map<String, dynamic> jsonData = await jsonDecode(response);

      if (jsonData.containsKey('Num_objs') && jsonData['Num_objs'] is int) {
        int numObjects = jsonData['Num_objs'];
        List<String> objectTypes = [];
        setState(() {
          flag = false;
        });
        for (var i = 0; i < numObjects; i++) {
          try {
            var obj = jsonData['Objects'][i];
            if (obj is Map<String, dynamic> &&
                obj.containsKey('Coordinated') &&
                obj['Coordinated'] is List &&
                obj['Object_type'] != null &&
                obj['Object_type'] is String &&
                obj['Probabilty'] != null &&
                obj['Probabilty'] is num &&
                obj['Probabilty'] > 0.45) {
              objectTypes.add(obj['Object_type']);

              List<double> coordinates =
                  List.castFrom<dynamic, double>(obj['Coordinated']);

              String direction = getGridLabel(coordinates, obj['Object_type']);
              _speakText('$direction');
            }
          } catch (e) {
            //_speakText("Error in processing object: $e");
          }
        }
        setState(() {
          flag = true;
        });
      } else {
        _speakText("No objects found");
      }
    } catch (e, stacktrace) {
      //_speakText('Error taking photo: $e');
      print(
          '######################################################Stacktrace: $stacktrace');
    }
  }

  String getGridLabel(List<double> coordinates, String objectType) {
    double centerX = (coordinates[0] + coordinates[2]) / 2;
    double centerY = (coordinates[1] + coordinates[3]) / 2;

    // Calculate grid position
    double gridWidth = _controller.value.previewSize!.width / 3;
    double gridHeight = _controller.value.previewSize!.height / 3;

    int col = (centerX / gridWidth).floor();
    int row = (centerY / gridHeight).floor();

    // Label the grid with direction and object type
    String direction = '';

    if (row == 0) {
      direction += 'Top';
    } else if (row == 1) {
      direction += 'Middle';
    } else {
      direction += 'Bottom';
    }

    if (col == 0) {
      direction += ' Left';
    } else if (col == 1) {
      direction += ' Center';
    } else {
      direction += ' Right';
    }

    return '$objectType at $direction';
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

  Future<void> resizeImage(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      List<int> imageBytes = imageFile.readAsBytesSync();
      img.Image? originalImage =
          img.decodeImage(Uint8List.fromList(imageBytes));
      if (originalImage != null) {
        final String resizedPath = join(
          (await getTemporaryDirectory()).path,
          'img2.jpg',
        );

        
        img.Image resizedImage =
            img.copyResize(originalImage, width: 640, height: 640);

        
        File(resizedPath).writeAsBytesSync(img.encodeJpg(resizedImage));

        
        await imageFile.delete();
      } else {
        print('Error decoding image: Image is null');
      }
    } catch (e) {
      print('Error resizing image: $e');
    }
  }

  void _startAutoCapture() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (flag ==true){
        _takeAndSavePhoto();
        setState(() {
          flag=false;
        });
      }
      
    });
  }

  Future<void> _speakText(String text) async {
    setState(() {
      Speech_temp = text;
      
    });
    await flutterTts.speak(Speech_temp);
    await Future.delayed(const Duration(seconds: 1, milliseconds: 800));
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
