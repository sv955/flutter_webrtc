import 'package:uuid/uuid.dart';

class WebRtcSessionId {
  String generate() {
    var uuid = const Uuid();
    String uniqueId = uuid.v4();
    return uniqueId;
  }
}
