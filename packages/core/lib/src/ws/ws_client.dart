import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../env/app_env.dart';

/// Minimal realtime client: connect / heartbeat / backoff reconnect / JSON stream.
///
/// The full Zuum protocol (topics, resume, location uplink) is implemented
/// in Milestone D against `docs/04_realtime_protocol.md`.
class ZwsClient {
  ZwsClient({String? baseUrl}) : baseUrl = baseUrl ?? AppEnv.wsBaseUrl;

  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _heartbeat;
  int _attempt = 0;
  bool _disposed = false;
  bool _manualClose = false;
  String? _topic;
  String? _token;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of decoded JSON messages from the server.
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  bool get isConnected => _channel != null && !_manualClose && !_disposed;

  void connect(String topic, {required String token}) {
    if (_disposed) return;
    _topic = topic;
    _token = token;
    _manualClose = false;
    _open();
  }

  void _open() {
    final topic = _topic;
    final token = _token;
    if (topic == null || token == null || _disposed || _manualClose) return;
    _reconnectTimer?.cancel();
    try {
      final uri = Uri.parse('$baseUrl/$topic/?token=${Uri.encodeComponent(token)}');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == 'pong') return;
        _controller.add(decoded);
      }
    } catch (_) {
      // Ignore malformed frames; server speaks JSON only.
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      send(const {'type': 'pong'});
    });
  }

  void _scheduleReconnect() {
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (_disposed || _manualClose || _topic == null) return;
    _attempt = min(_attempt + 1, 6);
    final baseMs = 500 * (1 << (_attempt - 1)); // 500ms → 16s cap at attempt 6
    final jitter = Random().nextInt(200);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: baseMs + jitter), _open);
  }

  void send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(message));
  }

  void disconnect() {
    _manualClose = true;
    _reconnectTimer?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }
}
