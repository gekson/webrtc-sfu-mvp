// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'widgets/chat_widget.dart';
import 'widgets/local_video_widget.dart';
import 'widgets/remote_videos_grid.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Configuration for different environments
  static const String _serverIP = String.fromEnvironment('SERVER_IP',
      defaultValue: '10.0.2.2'); // Default for Android emulator

  // Local media
  final _localRenderer = RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderers = [];
  MediaStream? _localStream;

  WebSocketChannel? _socket;
  late final RTCPeerConnection _peerConnection;

  // Add a log list to display connection status
  List<String> _logs = [];

  final GlobalKey<ChatWidgetState> _chatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    connect();
  }

  void _addLog(String log) {
    setState(() {
      _logs.add("${DateTime.now().toString().split('.').first}: $log");
      if (_logs.length > 10) {
        _logs.removeAt(0);
      }
    });
    print(log);
  }

  void _handleToggleCamera(bool isOn) async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = isOn;
    }
  }

  void _handleToggleMicrophone(bool isOn) async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = isOn;
    }
  }

  void _handleSendMessage(String message) {
    _socket?.sink.add(jsonEncode({
      "event": "chat",
      "data": message,
    }));
  }

  Future<void> connect() async {
    void _cleanupRenderer(MediaStream stream) {
      setState(() {
        _remoteRenderers.removeWhere((renderer) {
          if (renderer.srcObject?.id == stream.id) {
            renderer.dispose();
            return true;
          }
          return false;
        });
      });
    }

    try {
      _peerConnection = await createPeerConnection({}, {});

      await _localRenderer.initialize();
      _localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': true});
      _localRenderer.srcObject = _localStream;

      _localStream?.getTracks().forEach((track) async {
        await _peerConnection.addTrack(track, _localStream!);
      });

      _peerConnection.onIceCandidate = (candidate) {
        _socket?.sink.add(jsonEncode({
          "event": "candidate",
          "data": jsonEncode({
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
            'candidate': candidate.candidate,
          })
        }));
      };

      _peerConnection.onTrack = (event) async {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _addLog('Novo stream de vídeo recebido');
          var renderer = RTCVideoRenderer();
          await renderer.initialize();
          renderer.srcObject = event.streams[0];

          setState(() {
            if (!_remoteRenderers
                .any((r) => r.srcObject?.id == event.streams[0].id)) {
              _remoteRenderers.add(renderer);
            }
          });

          event.streams[0].onRemoveTrack = (track) {
            _addLog('Track removido: ${track.toString()}');
            _cleanupRenderer(event.streams[0]);
          };
        }
      };

      _peerConnection.onRemoveStream = (stream) {
        _addLog('Stream removido: ${stream.id}');
        _cleanupRenderer(stream);
      };

      final wsUrl = 'ws://$_serverIP:8080/websocket';
      _addLog("Conectando a $wsUrl");

      final socket = WebSocketChannel.connect(Uri.parse(wsUrl));
      _socket = socket;

      socket.stream.listen((raw) async {
        _addLog(
            "Mensagem recebida: ${raw.toString().substring(0, min(50, raw.toString().length))}...");
        Map<String, dynamic> msg = jsonDecode(raw);

        switch (msg['event']) {
          case 'candidate':
            final parsed = jsonDecode(msg['data']);
            _peerConnection
                .addCandidate(RTCIceCandidate(parsed['candidate'], '', 0));
            break;
          case 'offer':
            final offer = jsonDecode(msg['data']);
            await _peerConnection.setRemoteDescription(
                RTCSessionDescription(offer['sdp'], offer['type']));
            RTCSessionDescription answer =
                await _peerConnection.createAnswer({});
            await _peerConnection.setLocalDescription(answer);

            _socket?.sink.add(jsonEncode({
              'event': 'answer',
              'data': jsonEncode({'type': answer.type, 'sdp': answer.sdp}),
            }));
            break;
          case 'chat':
            _addLog('Mensagem de chat recebida: ${msg['data']}');
            if (_chatKey.currentState != null) {
              _chatKey.currentState!.addMessage(msg['data'], false);
            }
            break;
        }
      }, onDone: () {
        _addLog('Conexão WebSocket fechada');
      }, onError: (error) {
        _addLog('Erro WebSocket: $error');
      });
    } catch (e) {
      _addLog('Erro de conexão: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('WebRTC Chat'),
        ),
        body: Stack(
          children: [
            // Vídeo remoto em tela cheia
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: RemoteVideosGrid(
                  remoteRenderers: _remoteRenderers,
                ),
              ),
            ),
            // Chat flutuante com fundo semi-transparente
            Positioned(
              left: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.3,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ChatWidget(
                  key: _chatKey,
                  onSendMessage: _handleSendMessage,
                ),
              ),
            ),
            // Vídeo local flutuante
            Positioned(
              right: 16,
              bottom: 16,
              width: 180,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LocalVideoWidget(
                    localRenderer: _localRenderer,
                    onToggleCamera: _handleToggleCamera,
                    onToggleMicrophone: _handleToggleMicrophone,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (var renderer in _remoteRenderers) {
      renderer.dispose();
    }
    _socket?.sink.close();
    _peerConnection.close();
    super.dispose();
  }
}
