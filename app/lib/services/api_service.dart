import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reel.dart';

class SseEvent {
  final String event;
  final Map<String, dynamic> data;
  SseEvent({required this.event, required this.data});
}

class ApiService {
  static const String baseUrl = 'https://edureels.onrender.com/api';

  static Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return await user?.getIdToken();
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Streaming upload - returns SSE events as reels are generated
  static Stream<SseEvent> uploadPdfStream(
    String? filePath,
    String fileName,
    String subject, {
    Uint8List? fileBytes,
  }) async* {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');
    final uri = Uri.parse('$baseUrl/upload/stream');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['subject'] = subject;

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'pdf', fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'pdf', filePath,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ));
    }

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        try {
          final json = jsonDecode(body);
          throw Exception(json['error'] ?? 'Upload failed');
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Server error (${streamedResponse.statusCode})');
          }
          rethrow;
        }
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete SSE messages (separated by double newline)
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final message = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          String? event;
          String? data;

          for (final line in message.split('\n')) {
            if (line.startsWith('event: ')) {
              event = line.substring(7);
            } else if (line.startsWith('data: ')) {
              data = line.substring(6);
            }
          }

          if (event != null && data != null) {
            try {
              yield SseEvent(
                event: event,
                data: jsonDecode(data),
              );
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // Original bulk upload (kept for mobile fallback)
  static Future<Map<String, dynamic>> uploadPdf(
    String? filePath,
    String fileName,
    String subject, {
    Uint8List? fileBytes,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');
    final uri = Uri.parse('$baseUrl/upload');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['subject'] = subject;

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'pdf', fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'pdf', filePath,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Upload failed');
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Server error (${response.statusCode})');
        }
        rethrow;
      }
    }
  }

  static Future<List<Reel>> getReels({String? lastId, int limit = 10}) async {
    final headers = await _headers();
    String url = '$baseUrl/reels?limit=$limit';
    if (lastId != null) url += '&lastId=$lastId';

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['reels'] as List).map((r) => Reel.fromJson(r)).toList();
    }
    throw Exception('Failed to load reels');
  }

  static Future<List<Reel>> getMyReels() async {
    final headers = await _headers();
    final response =
        await http.get(Uri.parse('$baseUrl/reels/my'), headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['reels'] as List).map((r) => Reel.fromJson(r)).toList();
    }
    throw Exception('Failed to load reels');
  }

  static Future<bool> toggleLike(String reelId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/reels/$reelId/like'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['liked'];
    }
    throw Exception('Failed to like reel');
  }

  static Future<bool> toggleSave(String reelId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/reels/$reelId/save'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['saved'];
    }
    throw Exception('Failed to save reel');
  }

  static Future<void> trackView(String reelId) async {
    final headers = await _headers();
    await http.post(
      Uri.parse('$baseUrl/reels/$reelId/view'),
      headers: headers,
    );
  }
}
