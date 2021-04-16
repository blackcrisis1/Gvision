// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'detector_painters.dart';

class PictureScanner extends StatefulWidget {
  final String fileimg;
  PictureScanner({Key key, @required this.fileimg}) : super(key: key);
  @override
  State<StatefulWidget> createState() => _PictureScannerState(fileimg);
}

class _PictureScannerState extends State<PictureScanner> {
  //-------------------------------- TextToSpeech-
  FlutterTts flutterTts = new FlutterTts();
  String language = "th-TH";
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 1.0;
  //-------------------------------
  String pathimg = "";
  _PictureScannerState(fileimg) {
    pathimg = fileimg;
  }
  File _imageFile;
  Size _imageSize;
  dynamic _scanResults;
  dynamic _speakResults;
  Detector _currentDetector = Detector.cloudText;
  final BarcodeDetector _barcodeDetector =
      FirebaseVision.instance.barcodeDetector();
  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector();
  final ImageLabeler _imageLabeler = FirebaseVision.instance.imageLabeler();
  final ImageLabeler _cloudImageLabeler =
      FirebaseVision.instance.cloudImageLabeler();
  final TextRecognizer _recognizer = FirebaseVision.instance.textRecognizer();
  final TextRecognizer _cloudRecognizer =
      FirebaseVision.instance.cloudTextRecognizer();
  final DocumentTextRecognizer _cloudDocumentRecognizer =
      FirebaseVision.instance.cloudDocumentTextRecognizer();
  final ImagePicker _picker = ImagePicker();

  Future _speak(text_speak) async {
    await flutterTts.setLanguage(language);
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
    await flutterTts.speak(text_speak);
  }

  Future<void> _getAndScanImage() async {
    setState(() {
      _imageFile = null;
      _imageSize = null;
    });

    // final PickedFile pickedImage =
    //     await _picker.getImage(source: ImageSource.gallery);
    //await _picker.getImage(source: ImageSource.gallery);
    final File imageFile = File(pathimg);
    //final File imageFile = File(pickedImage.path);

    if (imageFile != null) {
      _getImageSize(imageFile);
      _scanImage(imageFile);
    }

    setState(() {
      _imageFile = imageFile;
    });
  }

  Future<void> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    setState(() {
      _imageSize = imageSize;
    });
  }

  Future<void> _scanImage(File imageFile) async {
    setState(() {
      _scanResults = null;
    });

    final FirebaseVisionImage visionImage =
        FirebaseVisionImage.fromFile(imageFile);

    dynamic results;
    try {
      switch (_currentDetector) {
        case Detector.barcode:
          results = await _barcodeDetector.detectInImage(visionImage);
          break;
        case Detector.face:
          results = await _faceDetector.processImage(visionImage);
          break;
        case Detector.label:
          results = await _imageLabeler.processImage(visionImage);
          break;
        case Detector.cloudLabel:
          results = await _cloudImageLabeler.processImage(visionImage);
          break;
        case Detector.text:
          results = await _recognizer.processImage(visionImage);
          break;
        case Detector.cloudText:
          results = await _cloudRecognizer.processImage(visionImage);
          break;
        case Detector.cloudDocumentText:
          results = await _cloudDocumentRecognizer.processImage(visionImage);
          break;
        default:
          return;
      }
    } catch (e) {
      print(e);
    }

    setState(() {
      if (results != null) {
        _scanResults = results;

        RegExp price_exp = new RegExp(r"[0-9]+\.[0-9][0-9]");
        RegExp productName_exp = new RegExp(r".*[ก-ฮ].*");

        var price = "";
        var productName = "";
        //print(_scanResults.blocks);
        for (var tb in _scanResults.blocks) {
          //print(tb.text);

          Iterable<RegExpMatch> price_matches = price_exp.allMatches(tb.text);
          if (price_matches.length > 0) {
            for (var pm in price_matches) {
              price = pm.group(0);
            }
          }

          Iterable<RegExpMatch> productName_matches =
              productName_exp.allMatches(tb.text);
          if (productName_matches.length > 0) {
            for (var pm in productName_matches) {
              if (pm.group(0).length > productName.length) {
                productName = pm.group(0);
              }
            }
          }
        }
        _speakResults = productName + " ราคา " + price + " บาท";
        print(_speakResults);
        print(pathimg);
        _speak(_speakResults);
        //_speak(_speakResults);
      }
    });
  }

  //-------------------------------- TextToSpeech
  //-------------------------------

  CustomPaint _buildResults(Size imageSize, dynamic results) {
    CustomPainter painter;

    try {
      switch (_currentDetector) {
        case Detector.barcode:
          painter = BarcodeDetectorPainter(_imageSize, results);
          break;
        case Detector.face:
          painter = FaceDetectorPainter(_imageSize, results);
          break;
        case Detector.label:
          painter = LabelDetectorPainter(_imageSize, results);
          break;
        case Detector.cloudLabel:
          painter = LabelDetectorPainter(_imageSize, results);
          break;
        case Detector.text:
          painter = TextDetectorPainter(_imageSize, results);
          break;
        case Detector.cloudText:
          painter = TextDetectorPainter(_imageSize, results);
          break;
        case Detector.cloudDocumentText:
          painter = DocumentTextDetectorPainter(_imageSize, results);
          break;
        default:
          break;
      }
    } catch (e) {
      print(e);
    }

    return CustomPaint(
      painter: painter,
    );
  }

  // Future<void> eiei() {
  //   setState(() {
  //     _speak("แตะหน้าจอสองครั้งเพื่อย้อนกลับ");
  //   });
  // }

  Widget _buildImage() {
    //_speak("แตะหน้าจอสองครั้งเพื่อย้อนกลับ");
    return GestureDetector(
      onDoubleTap: () => Navigator.pop(context),
      child: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Image.file(_imageFile).image,
            fit: BoxFit.scaleDown,
          ),
        ),
        child: _imageSize == null || _scanResults == null
            ? const Center(
                child: Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 30.0,
                  ),
                ),
              )
            : _buildResults(_imageSize, _scanResults),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผลลัพธ์การสแกน'),
        // actions: <Widget>[
        //   PopupMenuButton<Detector>(
        //     onSelected: (Detector result) {
        //       _currentDetector = result;
        //       if (_imageFile != null) _scanImage(_imageFile);
        //     },
        //     itemBuilder: (BuildContext context) => <PopupMenuEntry<Detector>>[
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Barcode'),
        //         value: Detector.barcode,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Face'),
        //         value: Detector.face,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Label'),
        //         value: Detector.label,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Cloud Label'),
        //         value: Detector.cloudLabel,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Text'),
        //         value: Detector.text,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Cloud Text'),
        //         value: Detector.cloudText,
        //       ),
        //       const PopupMenuItem<Detector>(
        //         child: Text('Detect Document Text'),
        //         value: Detector.cloudDocumentText,
        //       ),
        //     ],
        //   ),
        // ],
      ),
      body: _imageFile == null
          // ? GestureDetector(onDoubleTap: () => _getAndScanImage.call())
          ? _getAndScanImage.call()
          // ? GestureDetector(
          //     onDoubleTap: () => Navigator.pop(context),
          //   )
          : _buildImage(),
      // floatingActionButton: ElevatedButton(
      //   onPressed: () {
      //     Navigator.pop(context);
      //   },
      //   child: Text("ย้อนกลับ"),
      // ),
      // floatingActionButton: GestureDetector(
      //   onLongPress: () {
      //     Navigator.pop(context);
      //   },
      //   child: Text("ย้อนกลับ"),
      // ),
    );

    // return Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Picture Scanner'),
    //     ),
    //     body: GestureDetector(onDoubleTap: () => _getAndScanImage.call()));
  }

  @override
  void dispose() {
    _barcodeDetector.close();
    _faceDetector.close();
    _imageLabeler.close();
    _cloudImageLabeler.close();
    _recognizer.close();
    _cloudRecognizer.close();
    super.dispose();
  }
}
