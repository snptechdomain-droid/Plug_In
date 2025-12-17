import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;
  final _cursorController = StreamController<Map<String, dynamic>>.broadcast();
  final _nodeController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get cursorStream => _cursorController.stream;
  Stream<Map<String, dynamic>> get nodeStream => _nodeController.stream;

  bool get isConnected => _client?.connected ?? false;

  void connect(String projectId, String userId) {
    // Deactivate existing client to close open sockets/attempts
    if (_client != null) {
      _client!.deactivate();
    }

    // Hardcoded IP for mobile testing (Updated)
    String url = 'wss://snp-tech-backend.hf.space/ws';
    
    /* 
    String url = 'ws://localhost:8080/ws';
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        url = 'ws://10.0.2.2:8080/ws';
      } else {
        url = 'ws://localhost:8080/ws';
      }
    }
    */

    _client = StompClient(
      config: StompConfig(
        url: url,
        onConnect: (frame) => _onConnect(frame, projectId),
        onWebSocketError: (error) {
          print('WebSocket Error: $error');
          _scheduleReconnect(projectId, userId);
        },
        onStompError: (frame) {
          print('Stomp Error: ${frame.body}');
          _scheduleReconnect(projectId, userId);
        },
        onDisconnect: (frame) {
           print('Disconnected: ${frame.body}');
           _scheduleReconnect(projectId, userId);
        },
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 15),
      ),
    );

    _client!.activate();
  }

  void _scheduleReconnect(String projectId, String userId) {
    if (isConnected) return;
    print('Scheduling reconnect in 5 seconds...');
    Timer(const Duration(seconds: 5), () => connect(projectId, userId));
  }

  void _onConnect(StompFrame frame, String projectId) {
    print('Connected to WebSocket');
    
    // Subscribe to Cursor updates
    _client!.subscribe(
      destination: '/topic/project.$projectId.cursors',
      callback: (frame) {
        if (frame.body != null) {
          _cursorController.add(jsonDecode(frame.body!));
        }
      },
    );

    // Subscribe to Node updates
    _client!.subscribe(
      destination: '/topic/project.$projectId',
      callback: (frame) {
        if (frame.body != null) {
          _nodeController.add(jsonDecode(frame.body!));
        }
      },
    );
  }

  void sendCursorMove(String projectId, String userId, double x, double y, String color) {
    if (!isConnected) return;
    _client!.send(
      destination: '/app/project.moveCursor',
      body: jsonEncode({
        'projectId': projectId,
        'userId': userId,
        'x': x,
        'y': y,
        'color': color,
      }),
    );
  }

  void sendNodeUpdate(String projectId, String type, String nodeId, Map<String, dynamic> data) {
    if (!isConnected) return;
    _client!.send(
      destination: '/app/project.updateNode',
      body: jsonEncode({
        'type': type,
        'projectId': projectId,
        'nodeId': nodeId,
        'data': data,
      }),
    );
  }

  void sendConnection(String projectId, String type, Map<String, dynamic> data) {
    if (!isConnected) return;
    _client!.send(
      destination: '/app/project.updateNode', // Re-use updateNode endpoint as per protocol
      body: jsonEncode({
        'type': 'CONNECTION_$type', // e.g. CONNECTION_ADD
        'projectId': projectId,
        'nodeId': data['id'], // Connection ID as nodeId
        'data': data,
      }),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}
