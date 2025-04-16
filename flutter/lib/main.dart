// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'widgets/chat_widget.dart';
import 'widgets/local_video_widget.dart';
import 'widgets/remote_videos_grid.dart';
import 'screens/home_screen.dart';

// Classe para aceitar certificados SSL autoassinados
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }

  // Método estático para aplicar a configuração globalmente
  static void applyOverrides() {
    HttpOverrides.global = MyHttpOverrides();
    print('Configuração de segurança para certificados autoassinados aplicada');
  }
}

Future<void> main() async {
  // Carrega o arquivo .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Erro ao carregar arquivo .env: $e");
    // Tenta carregar de caminhos alternativos
    try {
      await dotenv.load(fileName: "../flutter/.env");
    } catch (e) {
      print(
          "Não foi possível carregar o arquivo .env de caminhos alternativos: $e");
    }
  }
  runApp(const AppWrapper());
}

// Wrapper para a aplicação
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Live Streaming',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

class MyApp extends StatefulWidget {
  final bool isHost;
  final String streamId;
  final String userId;
  final String streamTitle;

  const MyApp({
    super.key,
    required this.isHost,
    required this.streamId,
    required this.userId,
    required this.streamTitle,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Configuration for different environments
  static String get _serverIP {
    print('******* - SERVERIP:');
    return '129.153.236.194';
    // return '192.168.0.37';
    // // Tenta ler do arquivo .env primeiro
    // final envServerIP = dotenv.env['SERVER_IP'];
    // print(envServerIP);
    // if (envServerIP != null && envServerIP.isNotEmpty) return envServerIP;

    // // Verifica se está rodando no emulador Android
    // if (Platform.isAndroid) return '10.0.2.2';

    // // Fallback para desenvolvimento local
    // return '192.168.0.37';
  }

  static const bool _allowBadCertificates =
      true; // Permitir certificados autoassinados em desenvolvimento

  // Local media
  final _localRenderer = RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderers = [];
  MediaStream? _localStream;

  WebSocketChannel? _socket;
  late final RTCPeerConnection _peerConnection;

  // Add a log list to display connection status
  List<String> _logs = [];

  // Lista de usuários com permissão para ativar a câmera
  final List<String> _usersWithCameraPermission = [];

  // Controle de permissões
  bool get _canEnableCamera =>
      widget.isHost || _usersWithCameraPermission.contains(widget.userId);

  final GlobalKey<ChatWidgetState> _chatKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    print(
        'MyApp initState - isHost: ${widget.isHost}, streamId: ${widget.streamId}, userId: ${widget.userId}');

    // Aplicar configuração de segurança antes de qualquer conexão
    MyHttpOverrides.applyOverrides();
    print('Iniciando conexão WebRTC segura');

    connect();

    // Envia informação sobre o tipo de usuário (host ou cliente)
    Future.delayed(const Duration(seconds: 1), () {
      print('Enviando informações do usuário para o servidor');
      if (_socket != null && _socket!.sink != null) {
        _socket?.sink.add(jsonEncode({
          "event": "user_info",
          "data": jsonEncode({
            "userId": widget.userId,
            "streamId": widget.streamId,
            "isHost": widget.isHost,
            "streamTitle": widget.streamTitle,
          }),
        }));
        print('Informações do usuário enviadas com sucesso');
      } else {
        print(
            'ERRO: Socket não está disponível para enviar informações do usuário');
      }
    });
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
    // Verifica se o usuário tem permissão para ativar a câmera
    if (!_canEnableCamera) {
      _addLog('Você não tem permissão para ativar a câmera');
      // Solicita permissão ao host
      _requestCameraPermission();
      return;
    }

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

  void _requestCameraPermission() {
    // Envia solicitação de permissão para o host
    _socket?.sink.add(jsonEncode({
      "event": "permission_request",
      "data": jsonEncode({
        "userId": widget.userId,
        "streamId": widget.streamId,
        "type": "camera",
      }),
    }));

    // Notifica o usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação de permissão enviada ao host')),
    );
  }

  void _grantCameraPermission(String userId) {
    // Apenas o host pode conceder permissões
    if (!widget.isHost) return;

    setState(() {
      _usersWithCameraPermission.add(userId);
    });

    // Notifica o usuário que recebeu a permissão
    _socket?.sink.add(jsonEncode({
      "event": "permission_granted",
      "data": jsonEncode({
        "userId": userId,
        "streamId": widget.streamId,
        "type": "camera",
      }),
    }));
  }

  void _handleSendMessage(String message) {
    _socket?.sink.add(jsonEncode({
      "event": "chat",
      "data": message,
    }));
  }

  Future<void> connect() async {
    print('Iniciando conexão WebRTC segura');

    // Desativar verificação de certificados antes de qualquer conexão
    if (_allowBadCertificates) {
      // Configuração para ambiente de desenvolvimento - aceita certificados autoassinados
      HttpOverrides.global = MyHttpOverrides();
      print('Configuração de segurança para desenvolvimento aplicada');
    }

    // Conectar ao WebSocket usando WSS
    final wsUrl = 'wss://$_serverIP:8080/websocket';
    print('Conectando ao WebSocket: $wsUrl');

    try {
      // Simplificar a conexão WebSocket para evitar problemas com certificados
      final socket = await WebSocket.connect(wsUrl);
      _socket = IOWebSocketChannel(socket);
      print('Conexão WebSocket estabelecida');

      // Configurar WebRTC após conexão WebSocket bem-sucedida
      await _setupWebRTC();

      // Configurar listener para mensagens WebSocket
      _setupWebSocketListeners();
    } catch (e) {
      print('Erro ao conectar ao WebSocket: $e');
      // Tenta reconectar após 5 segundos
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) connect();
      });
    }
  }

  Future<void> _setupWebRTC() async {
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
    } catch (e) {
      _addLog('Erro ao inicializar conexão WebRTC: $e');
      print('Erro ao inicializar conexão WebRTC: $e');
    }
  }

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

  void _setupWebSocketListeners() {
    _socket?.stream.listen((raw) async {
      print(
          "Mensagem WebSocket recebida: ${raw.toString().substring(0, min(30, raw.toString().length))}...");
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
          RTCSessionDescription answer = await _peerConnection.createAnswer({});
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
        case 'permission_request':
          final request = jsonDecode(msg['data']);
          if (widget.isHost && request['streamId'] == widget.streamId) {
            // Mostra diálogo de confirmação para o host
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Solicitação de Permissão'),
                content: Text(
                    'Usuário ${request['userId']} solicita permissão para ativar a câmera.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Recusar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _grantCameraPermission(request['userId']);
                      Navigator.pop(context);
                    },
                    child: const Text('Permitir'),
                  ),
                ],
              ),
            );
          }
          break;
        case 'permission_granted':
          final permission = jsonDecode(msg['data']);
          if (permission['userId'] == widget.userId &&
              permission['streamId'] == widget.streamId) {
            setState(() {
              _usersWithCameraPermission.add(widget.userId);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Permissão concedida! Você pode ativar sua câmera agora.')),
            );
          }
          break;
      }
    }, onDone: () {
      _addLog('Conexão WebSocket fechada');
    }, onError: (error) {
      _addLog('Erro WebSocket: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isHost
            ? 'Transmissão: ${widget.streamTitle}'
            : 'Assistindo: ${widget.streamTitle}'),
        actions: [
          if (widget.isHost)
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Funcionalidade em desenvolvimento')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: RemoteVideosGrid(
                remoteRenderers: _remoteRenderers,
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).orientation == Orientation.landscape
                ? MediaQuery.of(context).size.height * 0.5
                : MediaQuery.of(context).size.height * 0.3,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ChatWidget(
                key: _chatKey,
                onSendMessage: _handleSendMessage,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            width: MediaQuery.of(context).orientation == Orientation.landscape
                ? 120
                : 180,
            height: MediaQuery.of(context).orientation == Orientation.landscape
                ? 90
                : 120,
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
                  canEnableCamera: _canEnableCamera,
                ),
              ),
            ),
          ),
        ],
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
