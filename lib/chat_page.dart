import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage(this.text, this.isUser);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  late WebSocketChannel _channel;
  bool _isConnected = false;

  List<ChatMessage> _messages = [];
  String _currentAssistantResponse = "";

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8000/ws'));

    _channel.stream.listen(
      (data) {
        if (data == "<|end|>") {
          // 응답 완료 시
          setState(() {
            _messages.add(ChatMessage(_currentAssistantResponse, false));
            _currentAssistantResponse = "";
          });
        } else {
          // 응답 중 (delta 수신)
          setState(() {
            _currentAssistantResponse += data;
          });
        }
      },
      onDone: () {
        setState(() {
          _isConnected = false;
        });
      },
      onError: (error) {
        print("WebSocket Error: $error");
        setState(() {
          _isConnected = false;
        });
      },
    );

    setState(() {
      _isConnected = true;
    });
  }

  void _sendMessage() {
    if (!_isConnected) _connectWebSocket();

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text, true));
      _currentAssistantResponse = "";
    });

    _channel.sink.add(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  Widget _buildMessage(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenAI Realtime Chat'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                ..._messages.map(_buildMessage),
                if (_currentAssistantResponse.isNotEmpty)
                  _buildMessage(ChatMessage(_currentAssistantResponse, false)),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: "질문을 입력하세요...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: const Text("보내기"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
