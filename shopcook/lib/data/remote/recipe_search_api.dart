import 'package:supabase_flutter/supabase_flutter.dart';

enum RecipeResultType { video, web }

class RecipeSearchResult {
  final RecipeResultType type;
  final String title;
  final String thumbnailUrl;
  final String url;
  final String source;

  RecipeSearchResult({
    required this.type,
    required this.title,
    required this.thumbnailUrl,
    required this.url,
    required this.source,
  });

  factory RecipeSearchResult.fromJson(Map<String, dynamic> json) {
    return RecipeSearchResult(
      type: json['type'] == 'video'
          ? RecipeResultType.video
          : RecipeResultType.web,
      title: json['title'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

/// Calls the `search-recipes` Supabase Edge Function, which queries the
/// YouTube Data API and a web search API server-side (keys never touch the
/// client). Returns an empty list if the function errors or the backend
/// hasn't been configured with search API keys yet.
class RecipeSearchApi {
  final SupabaseClient _client;

  RecipeSearchApi(this._client);

  Future<List<RecipeSearchResult>> search(String query) async {
    try {
      final response = await _client.functions.invoke(
        'search-recipes',
        body: {'query': query},
      );
      final data = response.data;
      if (data is! Map || data['results'] is! List) return [];
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(RecipeSearchResult.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
