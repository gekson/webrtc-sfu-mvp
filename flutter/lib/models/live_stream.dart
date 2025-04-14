class LiveStream {
  final String id;
  final String title;
  final String hostId;
  final List<String> viewers;
  final DateTime startTime;
  final bool isActive;

  LiveStream({
    required this.id,
    required this.title,
    required this.hostId,
    this.viewers = const [],
    required this.startTime,
    this.isActive = true,
  });

  // Método para adicionar um espectador
  LiveStream addViewer(String viewerId) {
    if (!viewers.contains(viewerId)) {
      final updatedViewers = List<String>.from(viewers)..add(viewerId);
      return copyWith(viewers: updatedViewers);
    }
    return this;
  }

  // Método para remover um espectador
  LiveStream removeViewer(String viewerId) {
    if (viewers.contains(viewerId)) {
      final updatedViewers = List<String>.from(viewers)..remove(viewerId);
      return copyWith(viewers: updatedViewers);
    }
    return this;
  }

  // Método para encerrar a transmissão
  LiveStream end() {
    return copyWith(isActive: false);
  }

  // Método para criar uma cópia com alterações
  LiveStream copyWith({
    String? id,
    String? title,
    String? hostId,
    List<String>? viewers,
    DateTime? startTime,
    bool? isActive,
  }) {
    return LiveStream(
      id: id ?? this.id,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      viewers: viewers ?? this.viewers,
      startTime: startTime ?? this.startTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
