import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class LocalVideoWidget extends StatefulWidget {
  final RTCVideoRenderer localRenderer;
  final Function(bool) onToggleCamera;
  final Function(bool) onToggleMicrophone;
  final bool canEnableCamera;

  const LocalVideoWidget({
    Key? key,
    required this.localRenderer,
    required this.onToggleCamera,
    required this.onToggleMicrophone,
    this.canEnableCamera = true,
  }) : super(key: key);

  @override
  State<LocalVideoWidget> createState() => _LocalVideoWidgetState();
}

class _LocalVideoWidgetState extends State<LocalVideoWidget> {
  bool _isCameraOn = true;
  bool _isMicrophoneOn = true;

  void _toggleCamera() {
    // Verifica se o usuário tem permissão para ativar a câmera
    if (!widget.canEnableCamera && !_isCameraOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Você não tem permissão para ativar a câmera')),
      );
      return;
    }

    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    widget.onToggleCamera(_isCameraOn);
  }

  void _toggleMicrophone() {
    setState(() {
      _isMicrophoneOn = !_isMicrophoneOn;
    });
    widget.onToggleMicrophone(_isMicrophoneOn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: RTCVideoView(
              widget.localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: _isCameraOn
                    ? Colors.green
                    : (widget.canEnableCamera ? Colors.red : Colors.grey),
                child: IconButton(
                  icon: Icon(
                    _isCameraOn ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                  ),
                  onPressed: _toggleCamera,
                  tooltip: widget.canEnableCamera
                      ? 'Alternar câmera'
                      : 'Solicitar permissão para câmera',
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                backgroundColor: _isMicrophoneOn ? Colors.green : Colors.red,
                child: IconButton(
                  icon: Icon(
                    _isMicrophoneOn ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                  onPressed: _toggleMicrophone,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
