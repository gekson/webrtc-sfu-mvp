import 'dart:convert';
import '../models/live_stream.dart';

class StreamService {
  // Singleton pattern
  static final StreamService _instance = StreamService._internal();
  factory StreamService() => _instance;
  StreamService._internal();

  // Lista de transmissões ativas (em memória)
  final List<LiveStream> _activeStreams = [];

  // Métodos para gerenciar transmissões
  List<LiveStream> getActiveStreams() {
    return List.from(_activeStreams.where((stream) => stream.isActive));
  }

  LiveStream? getStreamById(String streamId) {
    try {
      return _activeStreams.firstWhere((stream) => stream.id == streamId);
    } catch (e) {
      return null;
    }
  }

  // Criar uma nova transmissão
  LiveStream createStream(String title, String hostId) {
    final streamId = 'stream_${DateTime.now().millisecondsSinceEpoch}';
    final newStream = LiveStream(
      id: streamId,
      title: title,
      hostId: hostId,
      startTime: DateTime.now(),
    );

    _activeStreams.add(newStream);
    return newStream;
  }

  // Adicionar espectador a uma transmissão
  bool addViewerToStream(String streamId, String viewerId) {
    final streamIndex = _activeStreams.indexWhere((s) => s.id == streamId);
    if (streamIndex >= 0) {
      final updatedStream = _activeStreams[streamIndex].addViewer(viewerId);
      _activeStreams[streamIndex] = updatedStream;
      return true;
    }
    return false;
  }

  // Remover espectador de uma transmissão
  bool removeViewerFromStream(String streamId, String viewerId) {
    final streamIndex = _activeStreams.indexWhere((s) => s.id == streamId);
    if (streamIndex >= 0) {
      final updatedStream = _activeStreams[streamIndex].removeViewer(viewerId);
      _activeStreams[streamIndex] = updatedStream;
      return true;
    }
    return false;
  }

  // Encerrar uma transmissão
  bool endStream(String streamId) {
    final streamIndex = _activeStreams.indexWhere((s) => s.id == streamId);
    if (streamIndex >= 0) {
      final updatedStream = _activeStreams[streamIndex].end();
      _activeStreams[streamIndex] = updatedStream;
      return true;
    }
    return false;
  }

  // Verificar se um usuário é o host de uma transmissão
  bool isStreamHost(String streamId, String userId) {
    final stream = getStreamById(streamId);
    return stream != null && stream.hostId == userId;
  }

  // Serializar para JSON (para enviar ao servidor)
  String serializeStreams() {
    final List<Map<String, dynamic>> serialized = _activeStreams
        .where((stream) => stream.isActive)
        .map((stream) => {
              'id': stream.id,
              'title': stream.title,
              'hostId': stream.hostId,
              'viewers': stream.viewers,
              'startTime': stream.startTime.toIso8601String(),
              'isActive': stream.isActive,
            })
        .toList();

    return jsonEncode(serialized);
  }

  // Deserializar do JSON (ao receber do servidor)
  void deserializeStreams(String json) {
    final List<dynamic> data = jsonDecode(json);
    _activeStreams.clear();

    for (var item in data) {
      _activeStreams.add(LiveStream(
        id: item['id'],
        title: item['title'],
        hostId: item['hostId'],
        viewers: List<String>.from(item['viewers']),
        startTime: DateTime.parse(item['startTime']),
        isActive: item['isActive'],
      ));
    }
  }
}
