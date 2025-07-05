import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isLoading;
  final bool animateText;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.animateText = false,
  });

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with TickerProviderStateMixin {
  List<AnimationController>? _controllers;
  List<Animation<Offset>>? _offsetAnimations;
  String _animatedText = "";
  int _textIndex = 0;
  Timer? _typingTimer;

  void _startLoadingAnimation() {
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600),
      )..repeat(reverse: true),
    );
    _offsetAnimations = List.generate(3, (index) {
      final start = index * 0.15;
      final end = start + 0.7;
      return Tween<Offset>(begin: Offset(0, 0.3), end: Offset(0, -0.3)).animate(
        CurvedAnimation(
          parent: _controllers![index],
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  void _disposeLoadingAnimation() {
    if (_controllers != null) {
      for (var controller in _controllers!) {
        controller.dispose();
      }
      _controllers = null;
      _offsetAnimations = null;
    }
  }

  void _startTypingAnimation() {
    _animatedText = "";
    _textIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _textIndex++;
        if (_textIndex > widget.text.length) {
          timer.cancel();
          _animatedText = widget.text;
        } else {
          _animatedText = widget.text.substring(0, _textIndex);
        }
      });
    });
  }

  void _disposeTypingAnimation() {
    _typingTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _startLoadingAnimation();
    } else if (!widget.isUser && widget.text.isNotEmpty && widget.animateText) {
      _startTypingAnimation();
    } else {
      _animatedText = widget.text;
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clean up old animations
    _disposeLoadingAnimation();
    _disposeTypingAnimation();
    if (widget.isLoading) {
      _startLoadingAnimation();
    } else if (!widget.isUser && widget.text.isNotEmpty && widget.animateText) {
      _startTypingAnimation();
    } else {
      _animatedText = widget.text;
    }
  }

  @override
  void dispose() {
    _disposeLoadingAnimation();
    _disposeTypingAnimation();
    super.dispose();
  }

  Widget _buildWobblingDots() {
    if (_offsetAnimations == null) return SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return SlideTransition(
          position: _offsetAnimations![index],
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMarkdownText(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) async {
        if (href != null) {
          Uri url = Uri.parse(href);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            debugPrint("Could not launch URL: $href");
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
        a: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildRichTextWithLinks(String text) {
    final urlRegex = RegExp(r"(https?:\/\/[^\s]+)");
    List<TextSpan> spans = [];

    text.splitMapJoin(
      urlRegex,
      onMatch: (match) {
        String url = match.group(0)!;
        spans.add(
          TextSpan(
            text: url,
            style: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold,
            ),
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () async {
                    final Uri uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      debugPrint("Could not launch URL: $url");
                    }
                  },
          ),
        );
        return url;
      },
      onNonMatch: (nonMatch) {
        spans.add(
          TextSpan(text: nonMatch, style: TextStyle(color: Colors.black)),
        );
        return nonMatch;
      },
    );

    return SelectableText.rich(
      TextSpan(children: spans),
      style: TextStyle(fontSize: 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color:
              widget.isUser
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
                  : Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.isUser ? 18 : 6),
            topRight: Radius.circular(widget.isUser ? 6 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border:
              widget.isUser
                  ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.2,
                  )
                  : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child:
            (widget.text.isEmpty && widget.isLoading)
                ? const SizedBox.shrink() // Prevents red screen if text is empty and loading
                : widget.isLoading
                ? _buildWobblingDots()
                : widget.isUser
                ? _buildMarkdownText(widget.text)
                : _buildMarkdownText(_animatedText),
      ),
    );
  }
}
