import 'dart:async';

import 'package:flutter/services.dart';

class ReceiveSharingIntent {
  static const MethodChannel _mChannel = const MethodChannel('receive_sharing_intent/messages');
  static const EventChannel _eChannelLink = const EventChannel("receive_sharing_intent/events-text");
  static const EventChannel _eChannelFile = const EventChannel("receive_sharing_intent/events-file");

  static Stream<String> _streamLink;
  static Stream<List<String>> _streamFile;

  /// Returns a [Future], which completes to one of the following:
  ///
  ///   * the initially stored link (possibly null), on successful invocation;
  ///   * a [PlatformException], if the invocation failed in the platform plugin.
  static Future<String> getInitialText() async {
    return await _mChannel.invokeMethod('getInitialText');
  }

  /// Returns a [Future], which completes to one of the following:
  ///
  ///   * the initially stored file (possibly null), on successful invocation;
  ///   * a [PlatformException], if the invocation failed in the platform plugin.
  static Future<List<String>> getInitialFile() async {
    final List<dynamic> initialFile = await _mChannel.invokeMethod('getInitialFile');
    return initialFile?.map((data) => data.toString())?.toList();
  }

  /// A convenience method that returns the initially stored link
  /// as a new [Uri] object.
  ///
  /// If the link is not valid as a URI or URI reference,
  /// a [FormatException] is thrown.
  static Future<Uri> getInitialTextAsUri() async {
    final String data = await getInitialText();
    if (data == null) return null;
    return Uri.parse(data);
  }

  /// A convenience method that returns the initially stored file uri
  /// as a new [Uri] object.
  ///
  /// If the link is not valid as a URI or URI reference,
  /// a [FormatException] is thrown.
  static Future<List<Uri>> getInitialFileAsUri() async {
    final List<String> data = await getInitialFile();
    if (data == null) return null;
    return data.map((value) => Uri.parse(value)).toList();
  }

  /// Sets up a broadcast stream for receiving incoming link change events.
  ///
  /// Returns a broadcast [Stream] which emits events to listeners as follows:
  ///
  ///   * a decoded data ([String]) event (possibly null) for each successful
  ///   event received from the platform plugin;
  ///   * an error event containing a [PlatformException] for each error event
  ///   received from the platform plugin.
  ///
  /// Errors occurring during stream activation or deactivation are reported
  /// through the `FlutterError` facility. Stream activation happens only when
  /// stream listener count changes from 0 to 1. Stream deactivation happens
  /// only when stream listener count changes from 1 to 0.
  ///
  /// If the app was started by a link intent or user activity the stream will
  /// not emit that initial one - query either the `getInitialText` instead.
  static Stream<String> getTextStream() {
    if (_streamLink == null) {
      _streamLink = _eChannelLink.receiveBroadcastStream("text").cast<String>();
    }
    return _streamLink;
  }

  /// Sets up a broadcast stream for receiving incoming file share change events.
  ///
  /// Returns a broadcast [Stream] which emits events to listeners as follows:
  ///
  ///   * a decoded data ([List]) event (possibly null) for each successful
  ///   event received from the platform plugin;
  ///   * an error event containing a [PlatformException] for each error event
  ///   received from the platform plugin.
  ///
  /// Errors occurring during stream activation or deactivation are reported
  /// through the `FlutterError` facility. Stream activation happens only when
  /// stream listener count changes from 0 to 1. Stream deactivation happens
  /// only when stream listener count changes from 1 to 0.
  ///
  /// If the app was started by a link intent or user activity the stream will
  /// not emit that initial one - query either the `getInitialPdf` instead.
  static Stream<List<String>> getFileStream() {
    if (_streamFile == null) {
      final stream = _eChannelFile.receiveBroadcastStream("file").cast<List<dynamic>>();
      _streamFile = stream.transform<List<String>>(
        new StreamTransformer<List<dynamic>, List<String>>.fromHandlers(
          handleData: (List<dynamic> data, EventSink<List<String>> sink) {
            if (data == null) {
              sink.add(null);
            } else {
              sink.add(data.map((value) => value as String).toList());
            }
          },
        ),
      );
    }
    return _streamFile;
  }

  /// A convenience transformation of the stream to a `Stream<Uri>`.
  ///
  /// If the value is not valid as a URI or URI reference,
  /// a [FormatException] is thrown.
  ///
  /// Refer to `getTextStream` about error/exception details.
  ///
  /// If the app was started by a share intent or user activity the stream will
  /// not emit that initial uri - query either the `getInitialTextAsUri` instead.
  static Stream<Uri> getTextStreamAsUri() {
    return getTextStream().transform<Uri>(
      new StreamTransformer<String, Uri>.fromHandlers(
        handleData: (String data, EventSink<Uri> sink) {
          if (data == null) {
            sink.add(null);
          } else {
            sink.add(Uri.parse(data));
          }
        },
      ),
    );
  }

  /// A convenience transformation of the stream to a `Stream<List<Uri>>`.
  ///
  /// If the value is not valid as a URI or URI reference,
  /// a [FormatException] is thrown.
  ///
  /// Refer to `getIntentDataStream` about error/exception details.
  ///
  /// If the app was started by a share intent or user activity the stream will
  /// not emit that initial uri - query either the `getInitialImageAsUri` instead.
  static Stream<List<Uri>> getFileStreamAsUri() {
    return getFileStream().transform<List<Uri>>(
      new StreamTransformer<List<String>, List<Uri>>.fromHandlers(
        handleData: (List<String> data, EventSink<List<Uri>> sink) {
          if (data == null) {
            sink.add(null);
          } else {
            sink.add(data.map((value) => Uri.parse(value)).toList());
          }
        },
      ),
    );
  }

  /// Call this method if you already consumed the callback
  /// and don't want the same callback again
  static void reset() {
    _mChannel.invokeMethod('reset').then((_) {});
  }
}
