import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey = dotenv.env['gemini-api'] ?? '';
  GenerativeModel? _model;
  GenerativeModel? _summaryModel; // New model for summary generation
  ChatSession? _chatSession;

  // Existing system prompt for chat
  String _systemPromptText = """..."""; // Keep your existing system prompt

  // New system prompt for summary generation
  final String _summaryPromptText = """
You are a safety analyst AI assistant. Your task is to analyze user complaints and 
generate concise, professional safety summaries with these guidelines:

1. Focus on key safety trends, risks, and improvement opportunities
2. Provide actionable recommendations
3. Include relevant statistics if available
4. Use professional but accessible language
5. Limit summaries to 100-150 words
6. Structure with:
   - Overview of safety status
   - Main concerns identified
   - Notable trends/patterns
   - Recommendations
7. Use bullet points only for recommendations

Example format:
"Safety analysis of [category] based on [N] reports shows... 
Key concerns include... 
Trend analysis reveals... 
Recommendations:
- First recommendation
- Second recommendation"
""";

  GeminiService();

  void _initializeModel() {
    if (_model != null) return;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-preview-04-17',
      apiKey: _apiKey,
      systemInstruction: Content.system(_systemPromptText),
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 8192,
      ),
    );
    _chatSession = _model!.startChat();
  }

  void _initializeSummaryModel() {
    if (_summaryModel != null) return;
    _summaryModel = GenerativeModel(
      model: 'gemini-1.5-flash', // Better for summarization
      apiKey: _apiKey,
      systemInstruction: Content.system(_summaryPromptText),
      generationConfig: GenerationConfig(
        temperature: 0.7, // More focused than chat
        topK: 40,
        topP: 0.9,
        maxOutputTokens: 1024, // Appropriate for summaries
      ),
    );
  }

  // Existing chat method
  Future<String> getResponse(String message) async {
    if (_model == null || _chatSession == null) {
      return "Error: Model not initialized. Please update the system prompt first.";
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      return response.text ?? "Error: No response received.";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  // NEW: Summary generation method
  Future<String> generateSummary(String context, String category) async {
    _initializeSummaryModel(); // Ensure model is initialized

    try {
      final prompt = """
Generate a safety summary for $category based on these complaints:
$context

Focus on:
1. Key safety trends and patterns
2. Most common issues
3. Risk areas
4. Actionable recommendations
""";

      final response = await _summaryModel!.generateContent([
        Content.text(prompt),
      ]);
      return response.text ?? "No summary available";
    } catch (e) {
      return "Error generating summary: ${e.toString()}";
    }
  }

  // Existing methods remain unchanged
  void resetChat() {
    if (_chatSession != null) {
      _chatSession = _model!.startChat();
    }
  }

  void updateSystemPrompt(String additionalPrompt) {
    _systemPromptText += "\n\n$additionalPrompt";
    _initializeModel();
  }
}
