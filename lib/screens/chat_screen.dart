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
  // Add this focus node
  final FocusNode _textFieldFocus = FocusNode();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize ChatService with compInfo
    _chatService = ChatService(widget.compInfo);
    
    // Add this to ensure the focus is properly initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Short delay to ensure the screen is fully built
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).unfocus();
        }
      });
    });
  }

  @override
  void dispose() {
    // Dispose your focus node
    _textFieldFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void sendMessage() async {
    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      chatMessages.add({"text": userMessage, "isUser": true});
      isLoading = true;
      _controller.clear();
    });

    // Keep focus after sending
    _textFieldFocus.requestFocus();

    String botResponse = await _chatService.getChatResponse(userMessage);

    setState(() {
      chatMessages.add({"text": botResponse, "isUser": false});
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SororiAI")),
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
                    // Add the focus node here
                    focusNode: _textFieldFocus,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    // This can help with keyboard issues
                    keyboardType: TextInputType.text,
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