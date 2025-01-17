import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:nc_photos/stream_extension.dart';
import 'package:nc_photos_plugin/nc_photos_plugin.dart';

class NativeEventListener<T> {
  NativeEventListener(this.listener);

  void begin() {
    if (_subscription != null) {
      _log.warning("[begin] Already listening");
      return;
    }
    _subscription = _mappedStream.whereType<T>().listen(listener);
  }

  void end() {
    if (_subscription == null) {
      _log.warning("[end] Already not listening");
      return;
    }
    _subscription?.cancel();
    _subscription = null;
  }

  static final _mappedStream =
      NativeEvent.stream.whereType<NativeEventObject>().map((ev) {
    switch (ev.event) {
      case FileExifUpdatedEvent._id:
        return FileExifUpdatedEvent.fromEvent(ev);

      case ImageProcessorUploadSuccessEvent._id:
        return ImageProcessorUploadSuccessEvent.fromEvent(ev);

      default:
        throw ArgumentError("Invalid event: ${ev.event}");
    }
  });

  final void Function(T) listener;
  StreamSubscription<T>? _subscription;

  final _log = Logger("event.native_event.NativeEventListener<${T.runtimeType}>");
}

class FileExifUpdatedEvent {
  const FileExifUpdatedEvent(this.fileIds);

  factory FileExifUpdatedEvent.fromEvent(NativeEventObject ev) {
    assert(ev.event == _id);
    assert(ev.data != null);
    final dataJson = jsonDecode(ev.data!) as Map;
    return FileExifUpdatedEvent((dataJson["fileIds"] as List).cast<int>());
  }

  NativeEventObject toEvent() => NativeEventObject(
        _id,
        jsonEncode({
          "fileIds": fileIds,
        }),
      );

  static const _id = "FileExifUpdatedEvent";

  final List<int> fileIds;
}

class ImageProcessorUploadSuccessEvent {
  const ImageProcessorUploadSuccessEvent();

  factory ImageProcessorUploadSuccessEvent.fromEvent(NativeEventObject ev) {
    assert(ev.event == _id);
    assert(ev.data == null);
    return const ImageProcessorUploadSuccessEvent();
  }

  static const _id = "ImageProcessorUploadSuccessEvent";
}
