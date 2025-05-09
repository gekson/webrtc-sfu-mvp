import 'package:flutter/material.dart';

class ChatWidget extends StatefulWidget {
  final Function(String) onSendMessage;

  const ChatWidget({Key? key, required this.onSendMessage}) : super(key: key);

  @override
  State<ChatWidget> createState() => ChatWidgetState();
}

class ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  void addMessage(String message, bool isMe) {
    setState(() {
      _messages.add(ChatMessage(message: message, isMe: isMe));
    });
    // Rola para a última mensagem
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmit() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage(message);
      addMessage(message, true);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ajusta o layout com base na orientação do dispositivo
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(4), // Padding reduzido
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return MessageBubble(
                message: message.message,
                isMe: message.isMe,
              );
            },
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 4), // Padding reduzido
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.symmetric(
              horizontal: 4,
              vertical:
                  isLandscape ? 2 : 8), // Margem reduzida em modo paisagem
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isLandscape
                          ? 14
                          : 16), // Fonte menor em modo paisagem
                  minLines: 1,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Digite sua mensagem...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: isLandscape
                        ? const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4) // Padding reduzido em modo paisagem
                        : const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                iconSize: isLandscape ? 20 : 24, // Ícone menor em modo paisagem
                onPressed: _handleSubmit,
                padding: EdgeInsets.zero, // Remove o padding do botão
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ajusta o layout com base na orientação do dispositivo
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: isLandscape ? 2 : 4, horizontal: isLandscape ? 4 : 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * (isLandscape ? 0.6 : 0.7),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8 : 12,
                vertical: isLandscape ? 4 : 8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.blue.withOpacity(0.8)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLandscape ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String message;
  final bool isMe;

  ChatMessage({required this.message, required this.isMe});
}
