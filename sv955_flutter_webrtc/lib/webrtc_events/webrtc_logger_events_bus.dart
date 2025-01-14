import 'package:event_bus/event_bus.dart';

final EventBus webRtcLogs = EventBus();

enum LoggerType { info, trace, error, exception }

class WebRtcLoggerEvent {
  final LoggerType loggerType;
  final String message;
  final Type className;

  WebRtcLoggerEvent(
      {required this.loggerType,
      required this.message,
      required this.className});
}
