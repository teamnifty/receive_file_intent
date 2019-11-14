import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription _intentDataStreamSubscription;
  List<String> _sharedFiles;
  dynamic _sharedText;
  List<String> _sharedPdfs;

  @override
  void initState() {
    super.initState();

    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getImageStream().listen((List<String> value) {
      setState(() {
        _sharedFiles = value;
        //dynamic test = File(value.first);
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing pdfs coming from outside the app while the app is in the memory
/*    _intentDataStreamSubscription =
        ReceiveSharingIntent.getPdfStream().listen((List<String> value) {
      setState(() {
        _sharedPdfs = value;
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });*/

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialImage().then((List<String> value) {
      setState(() {
        _sharedFiles = value;
      });
    });

    // For sharing pdfs coming from outside the app while the app is closed
/*    ReceiveSharingIntent.getInitialPdf().then((List<String> value) {
      setState(() {
        _sharedPdfs = value;
      });
    });*/

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream().listen((value) {
      setState(() {
        _sharedText = value;
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String value) {
      setState(() {
        _sharedText = value;
      });
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyleBold = const TextStyle(fontWeight: FontWeight.bold);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text("Shared files:", style: textStyleBold),
              Text(_sharedFiles?.join(",") ?? ""),
              SizedBox(height: 100),
              Text("Shared urls/text:", style: textStyleBold),
              Text(_sharedText ?? ""),
              SizedBox(height: 100),
              Text("Shared pdfs:", style: textStyleBold),
              Text(_sharedPdfs?.join(",") ?? ""),
            ],
          ),
        ),
      ),
    );
  }
}
