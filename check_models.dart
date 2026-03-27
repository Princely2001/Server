import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

const String apiKey = 'AIzaSyC57O1nAyt2Iv92MoX9Wzwohqdk4KaQufo';

void main() async {
  final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
  try {
    print("Checking available models...");
    // There isn't a direct listModels method in the simple client yet,
    // so we test the most common ones.

    final modelsToTest = ['gemini-1.5-flash', 'gemini-pro', 'gemini-1.0-pro'];

    for (var m in modelsToTest) {
      stdout.write("Testing $m... ");
      try {
        final testModel = GenerativeModel(model: m, apiKey: apiKey);
        await testModel.generateContent([Content.text("Hi")]);
        print("✅ AVAILABLE");
      } catch (e) {
        print("❌ FAILED (Not found or access denied)");
      }
    }
  } catch (e) {
    print(e);
  }
}