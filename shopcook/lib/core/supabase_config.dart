/// Supabase project config. The anon/publishable key is safe to ship in the
/// client — it only grants access allowed by the project's RLS policies and
/// the `search-recipes` Edge Function, which reads its real secrets
/// (YouTube / web search API keys) server-side.
class SupabaseConfig {
  static const String url = 'https://wqidsbhicyfufncxyqww.supabase.co';
  static const String publishableKey =
      'sb_publishable_oaYh7Ba38nsfR4GgU3OIxA_NNRpxgsZ';
}
