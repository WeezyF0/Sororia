import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isLoading;

  const ChatBubble({super.key, required this.text, required this.isUser, this.isLoading = false});

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  Timer? _colorTimer;
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();

    if (widget.isLoading) {
      _controllers = List.generate(
        3,
        (index) => AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 500),
        )..repeat(reverse: true),
      );

      _animations = _controllers.map((controller) {
        return Tween<double>(begin: 6.0, end: 10.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        );
      }).toList();

      // Change the active dot every 300ms in sequence
      _colorTimer = Timer.periodic(Duration(milliseconds: 300), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _activeDot = (_activeDot + 1) % 3;
        });
      });
    }
  }

  @override
  void dispose() {
    if (widget.isLoading) {
      _colorTimer?.cancel();
      for (var controller in _controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }


  Widget _buildWobblingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 3),
              width: _animations[index].value,
              height: _animations[index].value,
              decoration: BoxDecoration(
                color: index == _activeDot ? Colors.black : Colors.grey[600],
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildMarkdownText(String text) {
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
        p: TextStyle(color: Colors.black, fontSize: 15),
        a: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
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
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint("Could not launch URL: $url");
                }
              },
          ),
        );
        return url;
      },
      onNonMatch: (nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: TextStyle(color: Colors.black)));
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
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: widget.isUser ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(15),
        ),
        child: widget.isLoading
            ? _buildWobblingDots()
            : widget.text.contains("http") // Check if text contains links
                ? _buildRichTextWithLinks(widget.text)
                : _buildMarkdownText(widget.text),
      ),
    );
  }
}