class WebRtcIceConfiguration {
  static Map<String, dynamic> get getConfig {
    return {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    };
  }
}
