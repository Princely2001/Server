import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

void main(List<String> args) async {
  // 1. DYNAMIC PORT: Cloud providers like Render/Railway assign a port via environment variables
  final port = int.tryParse(Platform.environment['PORT'] ?? '8081') ?? 8081;

  // 2. SECURITY: Fetch API key from environment variables (DO NOT hardcode keys here)
  final apiKey = Platform.environment['OPENROUTER_API_KEY'] ?? '';

  if (apiKey.trim().isEmpty) {
    stderr.writeln('ERROR: OPENROUTER_API_KEY environment variable is not set.');
    // In production, we exit if the API key is missing to prevent silent failures
    exit(1);
  }

  final router = Router();

  // Health check for Cloud Providers to see if your service is "Alive"
  router.get('/health', (Request req) {
    return Response.ok(jsonEncode({'ok': true}), headers: {
      HttpHeaders.contentTypeHeader: 'application/json',
    });
  });

  router.post('/chat', (Request req) async {
    try {
      final body = await req.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final message = (data['message'] ?? '').toString().trim();
      final historyList = (data['history'] is List) ? (data['history'] as List) : const [];

      if (message.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'message is required'}),
            headers: {HttpHeaders.contentTypeHeader: 'application/json'});
      }

      final systemPrompt = '''
You are GlowGuard Assistant, focused ONLY on cosmetics, skincare, bleaching/whitening products, and ingredient safety.
- Explain ingredients in simple terms (what it is, why used, common risks).
- If user asks for diagnosis or medical treatment: give general guidance and suggest seeing a qualified clinician/pharmacist/dermatologist.
- If uncertain: say you’re not sure and suggest checking product label + consulting a professional.
- Be extra careful with bleaching/whitening: warn about mercury, high-dose hydroquinone misuse, topical steroids misuse, and counterfeit products.
- Keep answers concise (3–8 bullet points max) and practical.
''';

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      for (final item in historyList) {
        if (item is Map) {
          final role = (item['role'] ?? '').toString();
          final content = (item['content'] ?? '').toString();
          if (content.trim().isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        }
      }

      if (messages.isEmpty || messages.last['content'] != message) {
        messages.add({'role': 'user', 'content': message});
      }

      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'X-Title': 'GlowGuard Backend',
        },
        body: jsonEncode({
          'model': 'arcee-ai/trinity-large-preview:free',
          'messages': messages,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Response(502,
            body: jsonEncode({
              'error': 'Error from AI provider',
              'details': response.body
            }),
            headers: {HttpHeaders.contentTypeHeader: 'application/json'});
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      final reply = choices?.isNotEmpty == true
          ? (choices![0]['message']?['content'] ?? '').toString().trim()
          : '';

      return Response.ok(
        jsonEncode({'reply': reply}),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    } catch (e) {
      return Response(
        500,
        body: jsonEncode({'error': 'Server error', 'details': e.toString()}),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    }
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders()) // Allows your Flutter app to talk to this server
      .addHandler(router.call);

  // 3. ANY IPV4: Crucial for cloud hosting so the service can accept external traffic
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('✅ GlowGuard Cloud Backend running on port ${server.port}');
}