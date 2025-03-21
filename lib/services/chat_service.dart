import 'dart:async';
import 'serper_service.dart';
import 'gemini_service.dart';

class ChatService {
  final GeminiService _geminiService = GeminiService();
  final SerperService _serperService = SerperService();
  final Map<String, String> _cache = {}; 

  bool _waitingForUserConfirmation = false;
  String _pendingQuery = "";

  Future<String> getChatResponse(String userMessage) async {
    if (_waitingForUserConfirmation) {
      if (userMessage.toLowerCase().contains("yes")) {
        _waitingForUserConfirmation = false;
        String summaryQuery = await _geminiService.getResponse("Summarize this search request in one short sentence: $_pendingQuery");
        return await getWebSearchResponse(summaryQuery);
      } else {
        _waitingForUserConfirmation = false;
        return "Okay! Let me know if you need anything else.";
      }
    }

    String geminiResponse = await _geminiService.getResponse(userMessage);

    if (geminiResponse.contains("I can search online for you.")) {
      _waitingForUserConfirmation = true;
      _pendingQuery = userMessage;
      return "_I can search online for you. Would you like me to proceed? (Yes/No)_";
    }

    return geminiResponse;
  }

  Future<String> getWebSearchResponse(String query) async {
    if (_cache.containsKey(query)) return _cache[query]!;
    
    try {
      String searchResults = await _serperService.search(query).timeout(
        const Duration(seconds: 6),
        onTimeout: () => "The search took too long. Please try again later.",
      );
      
      _cache[query] = searchResults;
      return searchResults.isNotEmpty ? searchResults : "No relevant information found.";
    } catch (e) {
      return "Failed to fetch search results. Please check your internet connection.";
    }
  }
}