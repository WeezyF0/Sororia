import 'dart:async';
import 'serper_service.dart';
import 'gemini_service.dart';
import 'dart:convert';

class ChatService {
  final GeminiService _geminiService = GeminiService();
  final SerperService _serperService = SerperService();
  final Map<String, String> _cache = {}; // Properly typed cache

  bool _waitingForUserConfirmation = false;
  String _pendingQuery = "";

  Future<String> getChatResponse(String userMessage) async {
    if (_waitingForUserConfirmation) {
      // If the user said "yes," proceed with web search after safety check
      if (userMessage.toLowerCase().contains("yes")) {
        _waitingForUserConfirmation = false;
        
        // Use Gemini to check if the query is safe
        bool isSafe = await _checkQuerySafety(_pendingQuery);
        if (!isSafe) {
          return "I'm sorry, but I can't perform a web search for that query due to safety concerns.";
        }
        
        return await getWebSearchResponse(_pendingQuery);
      } else {
        _waitingForUserConfirmation = false;
        return "Okay! Let me know if you need anything else.";
      }
    }

    String rawGeminiResponse = await _geminiService.getResponse(userMessage);
    
    // Parse the JSON response to extract just the Text_Response
    String geminiResponse = _parseGeminiResponse(rawGeminiResponse);

    // If Gemini says it cannot provide real-time data, ask the user for web search
    if (_needsWebSearch(geminiResponse)) {
      _waitingForUserConfirmation = true;
      _pendingQuery = userMessage;
      return "_I don't have real-time data. Would you like me to search the web for this? (Yes/No)_";
    }

    return geminiResponse;
  }

  String _parseGeminiResponse(String rawResponse) {
    try {
      // Try to parse as JSON
      Map<String, dynamic> jsonResponse = jsonDecode(rawResponse);
      
      // Extract the Text_Response field
      if (jsonResponse.containsKey('Text_Response')) {
        return jsonResponse['Text_Response'] ?? "No text response available.";
      }
      
      // If there's no Text_Response field but the response is valid JSON
      return rawResponse;
    } catch (e) {
      // If not valid JSON or parsing fails, return the original response
      return rawResponse;
    }
  }

  Future<bool> _checkQuerySafety(String query) async {
    // Make a separate call to Gemini specifically for safety checking
    String safetyPrompt = "Please analyze this query and respond with ONLY 'SAFE' or 'UNSAFE'. " +
                         "If this query is asking for information about harmful, illegal, or dangerous activities " +
                         "such as creating weapons, hacking, illegal substances, or anything that could cause harm, " +
                         "respond with 'UNSAFE'. Otherwise, respond with 'SAFE'. Query: \"$query\"";
    
    String rawSafetyResponse = await _geminiService.getResponse(safetyPrompt);
    
    // Parse the safety response
    String safetyResponse = _parseGeminiResponse(rawSafetyResponse);
    
    return safetyResponse.trim().toUpperCase().contains("SAFE") &&
          !safetyResponse.trim().toUpperCase().contains("UNSAFE");
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

  bool _needsWebSearch(String response) {
    return response.contains("I don't have access to real-time information") ||
           response.contains("I cannot browse the internet") ||
           response.contains("I cannot directly") ||
           response.contains("For up-to-date details, check official sources") ||
           response.contains("My knowledge is limited to") ||
           response.contains("My training data only goes up to");
  }
}