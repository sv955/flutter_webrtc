import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'webrtc_events/webrtc_logger_events_bus.dart';

class WebrtcMediaStream {
  MediaStream? _localCameraStream;
  MediaStream? _remotePeerCameraStream;

  MediaStream? get getLocalCameraStream => _localCameraStream;
  MediaStream? get getRemotePeerCameraStream => _remotePeerCameraStream;

  bool get isLocalCameraStreamInitialized => _localCameraStream != null;

  void initRemoteCameraStream(MediaStream remotePeerCameraStream) {
    _remotePeerCameraStream?.dispose();
    _remotePeerCameraStream = remotePeerCameraStream;
  }

  Future<void> initLocalCameraStream() async {
    try {
      if (getLocalCameraStream != null) {
        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.trace,
            message: 'Local camera stream is already initialized.',
            className: runtimeType));
        return;
      }

      var hasCameraPermission = await _hasCameraPermission();
      if (!hasCameraPermission) {
        return;
      }

      var hasMicrophonePermission = await _hasMicrophonePermission();
      if (!hasMicrophonePermission) {
        return;
      }

      await _initLocalCameraStream();

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message: 'Camera and microphone permissions are granted',
          className: runtimeType));
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }
  }

  Future<void> _initLocalCameraStream() async {
    _localCameraStream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': false});
  }

  Future<bool> _hasCameraPermission() async {
    var cameraPermissionStatus = await Permission.camera.request();

    if (!cameraPermissionStatus.isGranted) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.error,
          message: 'Camera permission is not granted',
          className: runtimeType));
    }
    return cameraPermissionStatus.isGranted;
  }

  Future<bool> _hasMicrophonePermission() async {
    var microphonePermissionStatus = await Permission.microphone.request();

    if (!microphonePermissionStatus.isGranted) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.error,
          message: 'Microphone permission is not granted',
          className: runtimeType));
    }

    return microphonePermissionStatus.isGranted;
  }
}
