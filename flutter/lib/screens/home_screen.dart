import 'dart:math';
import 'package:flutter/material.dart';
import '../models/live_stream.dart';
import '../main.dart';
import 'dart:developer' as developer;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Lista temporária de transmissões ativas (simulada)
  final List<LiveStream> _activeStreams = [];
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Adiciona algumas transmissões de exemplo
    _addExampleStreams();
  }

  void _addExampleStreams() {
    // Apenas para demonstração - em um app real, isso viria do servidor
    if (_activeStreams.isEmpty) {
      setState(() {
        _activeStreams.add(
          LiveStream(
            id: 'stream1',
            title: 'Transmissão de Exemplo 1',
            hostId: 'host1',
            startTime: DateTime.now().subtract(const Duration(minutes: 30)),
            viewers: List.generate(
                Random().nextInt(10) + 1, (index) => 'viewer$index'),
          ),
        );
        _activeStreams.add(
          LiveStream(
            id: 'stream2',
            title: 'Transmissão de Exemplo 2',
            hostId: 'host2',
            startTime: DateTime.now().subtract(const Duration(minutes: 15)),
            viewers: List.generate(
                Random().nextInt(5) + 1, (index) => 'viewer$index'),
          ),
        );
      });
    }
  }

  void _showCreateStreamDialog() {
    developer.log('Abrindo diálogo de criação de transmissão');
    showDialog(
      context: context,
      barrierDismissible:
          false, // Impede que o diálogo seja fechado ao clicar fora dele
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Iniciar Nova Transmissão'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Título da transmissão',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = _titleController.text.trim();
              developer.log('Botão Iniciar pressionado, título: $title');
              if (title.isNotEmpty) {
                // Primeiro fecha o diálogo
                Navigator.pop(dialogContext);
                // Depois inicia a transmissão
                _startNewStream(title);
              }
            },
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    developer.log('Diálogo de criação exibido');
  }

  void _startNewStream(String title) {
    // Gera um ID único para a transmissão
    final streamId = 'stream_${DateTime.now().millisecondsSinceEpoch}';
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    developer.log(
        'Iniciando nova transmissão: $title, streamId: $streamId, userId: $userId');

    try {
      // Em um app real, enviaria esses dados para o servidor
      // Aqui apenas navegamos para a tela de transmissão como host
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => MyApp(
                isHost: true,
                streamId: streamId,
                userId: userId,
                streamTitle: title,
              ),
            ),
          )
          .then((_) => developer.log('Retorno da tela de transmissão'));

      developer.log('Navegação iniciada com sucesso');
    } catch (e) {
      developer.log('Erro ao navegar para tela de transmissão: $e');
      // Mostrar mensagem de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar transmissão: $e')),
      );
    }
  }

  void _joinStream(LiveStream stream) {
    // Gera um ID único para o usuário
    final userId = 'viewer_${DateTime.now().millisecondsSinceEpoch}';

    // Em um app real, enviaria esses dados para o servidor
    // Aqui apenas navegamos para a tela de transmissão como espectador
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyApp(
          isHost: false,
          streamId: stream.id,
          userId: userId,
          streamTitle: stream.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmissões Ao Vivo'),
        backgroundColor: Colors.blue,
      ),
      body: _activeStreams.isEmpty
          ? const Center(child: Text('Nenhuma transmissão ativa no momento'))
          : ListView.builder(
              itemCount: _activeStreams.length,
              itemBuilder: (context, index) {
                final stream = _activeStreams[index];
                return StreamCard(
                  stream: stream,
                  onJoin: () => _joinStream(stream),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateStreamDialog,
        child: const Icon(Icons.video_call),
        tooltip: 'Iniciar transmissão',
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

class StreamCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onJoin;

  const StreamCard({
    Key? key,
    required this.stream,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calcula há quanto tempo a transmissão está ativa
    final duration = DateTime.now().difference(stream.startTime);
    final durationText = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes % 60}m'
        : '${duration.inMinutes}m ${duration.inSeconds % 60}s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          stream.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text('Ao vivo há $durationText'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16),
                const SizedBox(width: 4),
                Text('${stream.viewers.length} espectadores'),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Entrar'),
        ),
      ),
    );
  }
}
