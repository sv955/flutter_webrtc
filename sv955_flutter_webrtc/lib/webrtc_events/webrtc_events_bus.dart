import 'package:event_bus/event_bus.dart';

final EventBus webRtcEvents = EventBus();

enum WebRtcSendingEventType {
  informThatOfferCreated,
  informThatAnswerCreated,
  informThatIceCandidateReadyToShare,
  informThatConnectonIsEstablished,
  informThatRemotePeerVideoRecieved,
  informServerToTerminateCurrentSession,
}

enum WebRtcHandlingEventType {
  handleRequestToCreateOffer,
  handleCallerOffer,
  handleCalleeAnswer,
  handleIceCandidate,
  handleWebRtcConnectionTerminationRequest,
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
