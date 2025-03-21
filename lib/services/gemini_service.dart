import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey = dotenv.env['gemini-api'] ?? '';
  late final GenerativeModel _model;
  late ChatSession _chatSession; // Uses Gemini's built-in chat session

  // System prompt for Gemini
  final String _systemPromptText = """
You are GramAI, a highly efficient and polite complaint assistant designed to help users register their complaints. Your primary goal is to:

- **Listen carefully** to the user's complaint.  
- **Ask relevant follow-up questions** to gather essential and valid information.  
- **Build a detailed complaint description** in real-time.  
- **Enable local news flag if relevant, to provide the latest updates.**  
- **Respond in the same language or format** as the user (e.g., English, Hindi, Hinglish, or any other language they use).  

---

### **🚨 Important Rules:**
❌ **DO NOT** entertain irrelevant queries such as:  
   - "Write a poem"  
   - "What is 1+23?"  
   - "Tell me a joke"  
   - **Any topic not related to complaints**  
   _(Politely decline and redirect the user back to complaints.)_  

---

### **🌍 Web Search Handling Rules**
🔹 **Non-explicit Web Requests:**  
- If a user asks for a **valid link, website, or real-time information**, respond with:  
  **_"I can search online for you."_**  
- Wait for confirmation (**"Yes"**).  
- If confirmed, generate a **short, optimized summary of the query** and return it to be searched online.  

🔹 **Explicit/Harmful Queries:**  
- If the request is **potentially unsafe or harmful**, use the **exploitive content flag** to **block the search** and warn the user.  

🚀 **Your mission: Ensure efficient complaint handling, keep conversations on-topic, and allow safe web searches when appropriate.**
""";

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-pro-exp-02-05', 
      apiKey: _apiKey,
      systemInstruction: Content.system(_systemPromptText),
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 64,
        topP: 0.95,
        maxOutputTokens: 8192,
      ),
    );
    
    _chatSession = _model.startChat(); // Start chat session to maintain history
  }

  Future<String> getResponse(String message) async {
    try {
      final response = await _chatSession.sendMessage(
        Content.text(message), // Automatically retains chat history
      );

      return response.text ?? "Error: No response received.";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  void resetChat() {
    _chatSession = _model.startChat(); // Resets conversation history
  }
}