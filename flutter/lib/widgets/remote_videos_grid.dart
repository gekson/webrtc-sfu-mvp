import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteVideosGrid extends StatelessWidget {
  final List<RTCVideoRenderer> remoteRenderers;

  const RemoteVideosGrid({Key? key, required this.remoteRenderers})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Calcula o número de colunas com base na largura disponível
          int crossAxisCount = (width / 200).floor();
          crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;

          if (remoteRenderers.isEmpty) {
            return const Center(
              child: Text(
                'Aguardando participantes...',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (remoteRenderers.length == 1) {
            // Se houver apenas um vídeo, ele ocupa toda a tela
            return Container(
              width: width,
              height: height,
              child: RTCVideoView(
                remoteRenderers[0],
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: remoteRenderers.length,
            itemBuilder: (context, index) {
              return Container(
                color: Colors.black,
                child: RTCVideoView(
                  remoteRenderers[index],
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
