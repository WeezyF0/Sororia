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
  final ScrollController _scrollController =
      ScrollController(); // Add scroll controller
  List<Map<String, dynamic>> chatMessages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(widget.compInfo);

    // Add a more engaging greeting message from the bot when the chat starts
    if (chatMessages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          chatMessages.add({
            "text":
                "👋 Hi there! I'm SororiAI. How can I assist you today? Feel free to ask me anything or share your concerns.",
            "isUser": false,
          });
        });
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textFieldFocus.dispose();
    _controller.dispose();
    _scrollController.dispose();
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
    _scrollToBottom();
    _textFieldFocus.requestFocus();

    String botResponse = await _chatService.getChatResponse(userMessage);

    if (mounted) {
      setState(() {
        chatMessages.add({"text": botResponse, "isUser": false});
        isLoading = false;
      });
      _scrollToBottom();
      _textFieldFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(80.0),
          child: AppBar(
            centerTitle: true,
            title: Text(
              "SororiAI",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 24,
                color: Theme.of(context).appBarTheme.foregroundColor,
                shadows: [
                  Shadow(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.purple.withOpacity(0.2)
                            : Colors.pink.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // WhatsApp style
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 2,
                ),
                itemCount: chatMessages.length + (isLoading ? 1 : 0),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemBuilder: (context, index) {
                  if (isLoading && index == 0) {
                    // Only the topmost (latest) bubble shows loading
                    return const ChatBubble(
                      text: "",
                      isUser: false,
                      isLoading: true,
                    );
                  }
                  int reversedIndex =
                      chatMessages.length - 1 - (isLoading ? index - 1 : index);
                  if (isLoading) {
                    reversedIndex = chatMessages.length - index;
                  } else {
                    reversedIndex = chatMessages.length - 1 - index;
                  }
                  if (reversedIndex < 0 ||
                      reversedIndex >= chatMessages.length) {
                    return const SizedBox.shrink();
                  }
                  final message = chatMessages[reversedIndex];
                  // Animate text only for the latest bot message (not loading)
                  bool isLatestBot =
                      !isLoading &&
                      !message["isUser"] &&
                      reversedIndex ==
                          chatMessages.lastIndexWhere((m) => !m["isUser"]);
                  return ChatBubble(
                    text: message["text"],
                    isUser: message["isUser"],
                    isLoading: false, // Always false for normal chat bubbles
                    animateText: isLatestBot,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _textFieldFocus,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[900]
                                : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.15),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: sendMessage,
                    ),
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
