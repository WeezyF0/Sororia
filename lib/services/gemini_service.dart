import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey = dotenv.env['gemini-api'] ?? '';
  late final GenerativeModel _model;
  late final ChatSession _chatSession; 

  // System prompt text for GramSewa application
  final String _systemPromptText = """
Hello you are helpful complaint bot you must help people with their complaints, you must ask more questions and try to get as much information as possible from the user regarding the complaint,
Be extremely helpful and polite and find ways to help them in any and all manners. 
also you might want the user to see the local news for the complaint for that turn the news flag on. 
You must simultaneously build the complaint description describing the complaint of the user in some detail, 
some of your users might not know english, respond in the exact dialect and script the user enters their complaint in, 
for example: Roman alphabets get roman outputs, devnagri get devanagri and so on for all the different languages and dialects,
the complaint may be in any indian language or dialect.
""";

  GeminiService() {
    // Create the model with the system prompt and JSON schema response
    _model = GenerativeModel(
      model: 'gemini-2.0-pro-exp-02-05', 
      apiKey: _apiKey,
      // Using Content.system for system instruction
      systemInstruction: Content.system(_systemPromptText),
      // Configure generation parameters including JSON schema
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
        responseSchema: Schema(
          SchemaType.object,
          requiredProperties: ["Respond", "Text_Response", "News", "Complaint Description"],
          properties: {
            "Respond": Schema(
              SchemaType.boolean,
            ),
            "Text_Response": Schema(
              SchemaType.string,
            ),
            "News": Schema(
              SchemaType.boolean,
            ),
            "Complaint Description": Schema(
              SchemaType.string,
            ),
          },
        ),
      ),
    );
    
    // Start the chat session
    _chatSession = _model.startChat();
  }

  Future<String> getResponse(String message) async {
    try {
      final response = await _chatSession.sendMessage(
        Content.text(message),
      );

      return response.text ?? "Error: No response received.";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  void resetChat() {
    // Reset chat session to clear context, but maintain the system prompt
    _chatSession = _model.startChat();
  }
}