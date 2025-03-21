import 'package:flutter/material.dart';
import 'package:complaints_app/services/chat_service.dart';
import 'chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = false; // Track Gemini's response state

  void sendMessage() async {
    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      chatMessages.add({"text": userMessage, "isUser": true});
      isLoading = true; // Show "..." animation
      _controller.clear();
    });

    String botResponse = await _chatService.getChatResponse(userMessage);

    setState(() {
      chatMessages.add({"text": botResponse, "isUser": false});
      isLoading = false; // Remove animation after response
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("GramAI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == chatMessages.length && isLoading) {
                  return ChatBubble(text: "", isUser: false, isLoading: true); // Show "..." animation
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