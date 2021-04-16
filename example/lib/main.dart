// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';

import 'camera_preview_scanner.dart';
import 'material_barcode_scanner.dart';
import 'picture_scanner.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

//-----------------------------------------CameraPreview-----------------
class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver {
  CameraController controller;
  String imagePath;

  //-------------------------------- TextToSpeech-
  FlutterTts flutterTts = new FlutterTts();
  String language = "th-TH";
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 1.0;
  //-------------------------------
  Future _speak() async {
    await flutterTts.setLanguage(language);
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
  }

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected(controller.description);
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Center(
        child: GestureDetector(
          onDoubleTap: controller != null &&
                  controller.value.isInitialized &&
                  !controller.value.isRecordingVideo
              ? onTakePictureButtonPressed
              : null,
          child: Container(
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Center(
                child: _cameraPreviewWidget(),
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: controller != null && controller.value.isRecordingVideo
                    ? Colors.redAccent
                    : Colors.grey,
                width: 3.0,
              ),
            ),
          ),
        ),
      ),
    );
    // return Scaffold(
    //   key: _scaffoldKey,
    //   appBar: AppBar(
    //     title: const Text('Camera example'),
    //   ),
    //   body: Column(
    //     children: <Widget>[
    //       Expanded(
    //         child: Container(
    //           child: Padding(
    //             padding: const EdgeInsets.all(1.0),
    //             child: Center(
    //               child: _cameraPreviewWidget(),
    //             ),
    //           ),
    //           decoration: BoxDecoration(
    //             color: Colors.black,
    //             border: Border.all(
    //               color: controller != null && controller.value.isRecordingVideo
    //                   ? Colors.redAccent
    //                   : Colors.grey,
    //               width: 3.0,
    //             ),
    //           ),
    //         ),
    //       ),
    //       _captureControlRowWidget(),
    //       Padding(
    //         padding: const EdgeInsets.all(5.0),
    //         child: Row(
    //           mainAxisAlignment: MainAxisAlignment.start,
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      // children: <Widget>[
      //   ElevatedButton(
      //       onPressed: controller != null &&
      //               controller.value.isInitialized &&
      //               !controller.value.isRecordingVideo
      //           ? onTakePictureButtonPressed
      //           : null,
      //       child: Text("ถ่ายรูป"))
      children: <Widget>[
        GestureDetector(
            onDoubleTap: controller != null &&
                    controller.value.isInitialized &&
                    !controller.value.isRecordingVideo
                ? onTakePictureButtonPressed
                : null,
            child: Text("ถ่ายรูป"))
        // IconButton(
        //   icon: const Icon(Icons.camera_alt),
        //   color: Colors.blue,
        //   onPressed: controller != null &&
        //           controller.value.isInitialized &&
        //           !controller.value.isRecordingVideo
        //       ? onTakePictureButtonPressed
        //       : null,
        // ),
      ],
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    // ignore: deprecated_member_use
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
        });
        if (filePath != null) showInSnackBar('Picture saved to $filePath');
        // Navigate to second screen with data
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => PictureScanner(fileimg: imagePath)));
        _speak();
      }
    });
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(CameraApp());
}

//-----------------------------------------CameraPreview-----------------

// void main() {
//   runApp(
//     MaterialApp(
//       routes: <String, WidgetBuilder>{
//         '/': (BuildContext context) => _ExampleList(),
//         '/$PictureScanner': (BuildContext context) => PictureScanner(),
//         // '/$CameraPreviewScanner': (BuildContext context) =>
//         //     CameraPreviewScanner(),
//         // '/$MaterialBarcodeScanner': (BuildContext context) =>
//         //     const MaterialBarcodeScanner(),
//       },
//     ),
//   );
// }

// class _ExampleList extends StatefulWidget {
//   @override
//   State<StatefulWidget> createState() => _ExampleListState();
// }

// class _ExampleListState extends State<_ExampleList> {
//   static final List<String> _exampleWidgetNames = <String>[
//     '$PictureScanner',
//     // '$CameraPreviewScanner',
//     // '$MaterialBarcodeScanner',
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Example List'),
//       ),
//       body: ListView.builder(
//         itemCount: _exampleWidgetNames.length,
//         itemBuilder: (BuildContext context, int index) {
//           final String widgetName = _exampleWidgetNames[index];

//           return Container(
//             decoration: const BoxDecoration(
//               border: Border(bottom: BorderSide(color: Colors.grey)),
//             ),
//             child: ListTile(
//               title: Text(widgetName),
//               onTap: () => Navigator.pushNamed(context, '/$widgetName'),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
