import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

const String apiKey = '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';

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