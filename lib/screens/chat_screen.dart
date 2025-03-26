import 'package:flutter/material.dart';
import 'package:complaints_app/services/chat_service.dart';
import 'chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String compInfo; // Add this field to accept the argument

  const ChatScreen({super.key, required this.compInfo}); // Update constructor to require userId

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize ChatService with compInfo
    _chatService = ChatService(widget.compInfo);
  }

  void sendMessage() async {
    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      chatMessages.add({"text": userMessage, "isUser": true});
      isLoading = true;
      _controller.clear();
    });

    String botResponse = await _chatService.getChatResponse(userMessage);

    setState(() {
      chatMessages.add({"text": botResponse, "isUser": false});
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("UnioAI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == chatMessages.length && isLoading) {
                  return ChatBubble(text: "", isUser: false, isLoading: true);
                }
                final message = chatMessages[index];
                return ChatBubble(text: message["text"], isUser: message["isUser"]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}