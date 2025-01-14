import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_events/webrtc_events_bus.dart';
import 'webrtc_events/webrtc_logger_events_bus.dart';
import 'webrtc_ice_configuration.dart';
import 'webrtc_media_stream.dart';
import 'webrtc_session_id.dart';

class WebRtcService {
  late WebrtcMediaStream _webrtcMediaStream;
  late String _sessionId;
  late StreamSubscription<WebRtcHadlingEvent> _webRtcHadlingEventSubscription;

  RTCPeerConnection? _peerConnection;
  bool _isCaller = false;
  bool _informedServerAboutConnectionIsEstablished = false;

  final List<Map<String, dynamic>> _iceCandidateCollection = [];

  WebRtcService() {
    _webRtcHadlingEventSubscription =
        webRtcEvents.on<WebRtcHadlingEvent>().listen((event) {
      switch (event.eventType) {
        case WebRtcHandlingEventType.handleRequestToCreateOffer:
          _createOffer();
          break;
        case WebRtcHandlingEventType.handleCallerOffer:
          _createAnswer(event.eventData, event.sessionId!);
          break;
        case WebRtcHandlingEventType.handleCalleeAnswer:
          _handleCalleeAnswer(event.eventData);
          break;
        case WebRtcHandlingEventType.handleIceCandidate:
          _setRemotePeerIceCandidate(event.eventData);
          break;
        case WebRtcHandlingEventType.handleWebRtcConnectionTerminationRequest:
          _handlingCurrentSessionTerminationRequest();
          break;
      }
    });
  }

  void init(WebrtcMediaStream webrtcMediaStream) {
    _webrtcMediaStream = webrtcMediaStream;
  }

  //Peer connction instance
  Future<void> _createPeerConnectionInstance() async {
    if (_peerConnection != null) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.error,
          message: 'Peer connection already exists',
          className: runtimeType));
      return;
    }
    _peerConnection =
        await createPeerConnection(WebRtcIceConfiguration.getConfig);
  }

  //Create offer
  Future _createOffer() async {
    try {
      if (!_webrtcMediaStream.isLocalCameraStreamInitialized) {
        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.error,
            message: 'Web cam is not enabled for creating offer',
            className: runtimeType));
        return;
      }

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.info,
          message: "I'm caller and creating an offer",
          className: runtimeType));

      await _createPeerConnectionInstance();

      var localCameraStream = _webrtcMediaStream.getLocalCameraStream!;

      _setRemotePeerVideoStream();

      localCameraStream.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, localCameraStream);
      });

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        _iceCandidateCollection.clear();
        var candidateMap = candidate.toMap();
        _iceCandidateCollection.add(candidateMap);
      };

      var peerOffer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(peerOffer);

      _sessionId = WebRtcSessionId().generate();

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message:
              "I'm caller and created an offer with session id: $_sessionId",
          className: runtimeType));

      webRtcEvents.fire(WebRtcSendingEvent(
          eventType: WebRtcSendingEventType.informThatOfferCreated,
          eventData: peerOffer.sdp!,
          sessionId: _sessionId));

      _isCaller = true;
      _informedServerAboutConnectionIsEstablished = false;
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }
  }

  //Create Answer
  Future<void> _createAnswer(String offerSdp, String sessionId) async {
    try {
      if (!_webrtcMediaStream.isLocalCameraStreamInitialized) {
        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.error,
            message: 'Web cam is not enabled for creating answer',
            className: runtimeType));
        return;
      }

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.info,
          message: "I'm callee and creating an answer",
          className: runtimeType));

      await _createPeerConnectionInstance();

      var localCameraStream = _webrtcMediaStream.getLocalCameraStream!;

      _setRemotePeerVideoStream();

      localCameraStream.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, localCameraStream);
      });

      const sdpType = "offer";
      var remoteSessionDescripton = RTCSessionDescription(offerSdp, sdpType);
      await _peerConnection!.setRemoteDescription(remoteSessionDescripton);

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        _iceCandidateCollection.clear();
        var candidateMap = candidate.toMap();
        _iceCandidateCollection.add(candidateMap);

        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.info,
            message:
                "I'm callee and sending my ice to caller for session id: $_sessionId",
            className: runtimeType));

        var iceCandidateJsonString =
            _convertIceCandidateToJsonString(_iceCandidateCollection);

        if (iceCandidateJsonString.isEmpty) {
          return;
        }
        webRtcEvents.fire(WebRtcSendingEvent(
            eventType:
                WebRtcSendingEventType.informThatIceCandidateReadyToShare,
            eventData: iceCandidateJsonString,
            sessionId: _sessionId));

        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.trace,
            message:
                "I'm callee and I've send my ice to caller for session id: $_sessionId",
            className: runtimeType));
      };

      var answerSdp = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answerSdp);

      _sessionId = sessionId;

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message:
              "I'm callee and created an answer for session id: $_sessionId",
          className: runtimeType));

      webRtcEvents.fire(WebRtcSendingEvent(
          eventType: WebRtcSendingEventType.informThatAnswerCreated,
          eventData: answerSdp.sdp!,
          sessionId: _sessionId));

      _isCaller = false;
      _informedServerAboutConnectionIsEstablished = false;
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }
  }

  //Handle callee answer
  Future<void> _handleCalleeAnswer(String answerSdp) async {
    const sdpType = "answer";
    var remoteSessionDescripton = RTCSessionDescription(answerSdp, sdpType);
    await _peerConnection!.setRemoteDescription(remoteSessionDescripton);

    webRtcLogs.fire(WebRtcLoggerEvent(
        loggerType: LoggerType.trace,
        message:
            "I'm caller and recived callee answer for session id: $_sessionId",
        className: runtimeType));

    webRtcLogs.fire(WebRtcLoggerEvent(
        loggerType: LoggerType.info,
        message:
            "I'm caller and sending my ice to callee for session id: $_sessionId",
        className: runtimeType));

    var iceCandidateJsonString =
        _convertIceCandidateToJsonString(_iceCandidateCollection);

    if (iceCandidateJsonString.isEmpty) {
      return;
    }

    webRtcEvents.fire(WebRtcSendingEvent(
        eventType: WebRtcSendingEventType.informThatIceCandidateReadyToShare,
        eventData: iceCandidateJsonString,
        sessionId: _sessionId));
  }

  //Handling ice candidate from remote peer
  void _setRemotePeerIceCandidate(String jsonString) {
    final List<dynamic> decodedData = jsonDecode(jsonString) as List;

    for (var cadidateObj in decodedData) {
      var cadidate = jsonDecode(cadidateObj);
      var can = cadidate['candidate'];
      var sdpmid = cadidate['sdpMid'];
      var sdpIndex = cadidate['sdpMLineIndex'];
      var remoteIce = RTCIceCandidate(can, sdpmid, sdpIndex);
      _peerConnection!.addCandidate(remoteIce);
    }

    if (!_informedServerAboutConnectionIsEstablished) {
      var peerType = _isCaller ? "Caller" : "Callee";
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message:
              "I'm $peerType and informing server that connection is established for session: $_sessionId ",
          className: runtimeType));

      webRtcEvents.fire(WebRtcSendingEvent(
          eventType: WebRtcSendingEventType.informThatConnectonIsEstablished,
          eventData: '',
          sessionId: _sessionId));
      _informedServerAboutConnectionIsEstablished = true;
    }
  }

  String _convertIceCandidateToJsonString(
      List<Map<String, dynamic>> iceCandidate) {
    try {
      var iceCandidateJson =
          iceCandidate.map((map) => jsonEncode(map)).toList();

      var finalJson = jsonEncode(iceCandidateJson);

      return finalJson;
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }

    return '';
  }

  //Media stream from remote peer received
  void _setRemotePeerVideoStream() {
    try {
      _peerConnection?.onTrack = (RTCTrackEvent event) {
        if (event.streams.isEmpty) {
          return;
        }

        var peerType = _isCaller ? "Callee" : "Caller";

        webRtcLogs.fire(WebRtcLoggerEvent(
            loggerType: LoggerType.info,
            message:
                "Remote video stream has been received from from $peerType for session: $_sessionId ",
            className: runtimeType));

        _webrtcMediaStream.initRemoteCameraStream(event.streams[0]);

        webRtcEvents.fire(WebRtcSendingEvent(
            eventType: WebRtcSendingEventType.informThatRemotePeerVideoRecieved,
            eventData: '',
            sessionId: _sessionId));
      };
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }
  }

  //Reset peer connection
  void _resetPeerConnection() async {
    try {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message: "Removing current connection for session id: $_sessionId ",
          className: runtimeType));

      if (_peerConnection == null) {
        return;
      }

      List<RTCRtpTransceiver> transceiversCollection =
          await _peerConnection!.transceivers;

      for (var track in transceiversCollection) {
        await track.sender.track?.stop();
        await track.stop();
      }

      List<RTCRtpSender> senderCollection = await _peerConnection!.senders;

      for (var sender in senderCollection) {
        await sender.track?.stop();
      }

      await _peerConnection!.close();

      _peerConnection?.onTrack = null;

      _peerConnection = null;

      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.trace,
          message:
              "Current web rtc connection is closed for session id: $_sessionId ",
          className: runtimeType));

      _iceCandidateCollection.clear();
      _sessionId = '';
      _isCaller = false;
      _informedServerAboutConnectionIsEstablished = false;
    } catch (e) {
      webRtcLogs.fire(WebRtcLoggerEvent(
          loggerType: LoggerType.exception,
          message: e.toString(),
          className: runtimeType));
    }
  }

  void _handlingCurrentSessionTerminationRequest() {
    webRtcLogs.fire(WebRtcLoggerEvent(
        loggerType: LoggerType.info,
        message:
            "Informing server to terminate sesion of callee and caller for session: $_sessionId",
        className: runtimeType));

    webRtcEvents.fire(WebRtcSendingEvent(
        eventType: WebRtcSendingEventType.informServerToTerminateCurrentSession,
        eventData: '',
        sessionId: _sessionId));
  }

  void dispose() {
    _resetPeerConnection();
    _webRtcHadlingEventSubscription.cancel();
  }
}
