import 'package:event_bus/event_bus.dart';

final EventBus webRtcEvents = EventBus();

enum WebRtcSendingEventType {
  informThatOfferCreated,
  informThatAnswerCreated,
  informThatIceCandidateReadyToShare,
  informThatConnectonIsEstablished,
  informThatRemotePeerVideoRecieved,
  informServerToTerminateCurrentSession,
  informThatConnectionIsTerminatedAndVideoIsStopped,
}

enum WebRtcHandlingEventType {
  handleRequestToCreateOffer,
  handleCallerOffer,
  handleCalleeAnswer,
  handleIceCandidate,
  handleWebRtcConnectionTerminationResponse,
}

class WebRtcSendingEvent {
  final WebRtcSendingEventType eventType;
  final String eventData;
  final String? sessionId;

  WebRtcSendingEvent(
      {required this.eventType, required this.eventData, this.sessionId});
}

class WebRtcHadlingEvent {
  final WebRtcHandlingEventType eventType;
  final String eventData;
  final String? sessionId;

  WebRtcHadlingEvent(
      {required this.eventType, required this.eventData, this.sessionId});
}
