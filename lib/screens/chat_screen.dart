import 'package:flutter/material.dart';
import 'package:complaints_app/services/chat_service.dart';
import 'chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String compInfo;
  const ChatScreen({super.key, required this.compInfo});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.compInfo);

  }

  @override
  void dispose() {
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

    // Keep focus after sending - request focus explicitly
    _textFieldFocus.requestFocus();

    String botResponse = await _chatService.getChatResponse(userMessage);

    if (mounted) {
      setState(() {
        chatMessages.add({"text": botResponse, "isUser": false});
        isLoading = false;
      });
      
      // Request focus again after response
      _textFieldFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add this GestureDetector to prevent keyboard dismissal when tapping outside
      onTap: () {
        // Do nothing - prevent unfocus behavior
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("SororiAI")),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: chatMessages.length + (isLoading ? 1 : 0),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemBuilder: (context, index) {
                  if (index == chatMessages.length && isLoading) {
                    return const ChatBubble(text: "", isUser: false, isLoading: true);
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
                      focusNode: _textFieldFocus,
                      autofocus: true, // Add this to auto-focus the field initially
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send, // Add this to send on keyboard action
                      onSubmitted: (_) => sendMessage(), // Add this to handle keyboard send
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}