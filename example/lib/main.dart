import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_file_intent/receive_file_intent.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription _intentDataStreamSubscription;
  List<String> _sharedFiles;
  dynamic _sharedText;

  @override
  void initState() {
    super.initState();

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveFileIntent.getTextStream().listen((value) {
      setState(() {
        _sharedText = value;
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing files coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveFileIntent.getFileStream().listen((List<String> value) {
      setState(() {
        _sharedFiles = value;
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveFileIntent.getInitialText().then((String value) {
      setState(() {
        _sharedText = value;
      });
    });

    // For sharing files coming from outside the app while the app is closed
    ReceiveFileIntent.getInitialFile().then((List<String> value) {
      setState(() {
        _sharedFiles = value;
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
              //if(_sharedFiles != null) Image.file(File(_sharedFiles.first))
            ],
          ),
        ),
      ),
    );
  }
}
