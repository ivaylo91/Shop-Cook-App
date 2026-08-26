// Supabase Edge Function: search-recipes
//
// Proxies recipe search to YouTube + the web so the API keys never reach
// the mobile client. Reads secrets from the function's environment:
//   YOUTUBE_API_KEY   - Google Cloud "YouTube Data API v3" key
//   GOOGLE_CSE_KEY    - Google Custom Search JSON API key
//   GOOGLE_CSE_CX     - Google Programmable Search Engine ID
//
// Set these via the Supabase dashboard (Project Settings -> Edge Functions
// -> Secrets) or `supabase secrets set NAME=value`. Any source whose keys
// are missing is silently skipped rather than causing an error, so the app
// keeps working (with fewer results) before secrets are configured.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RecipeResult {
  type: "video" | "web";
  title: string;
  thumbnailUrl: string;
  url: string;
  source: string;
}

async function searchYouTube(query: string): Promise<RecipeResult[]> {
  const apiKey = Deno.env.get("YOUTUBE_API_KEY");
  if (!apiKey) return [];

  const params = new URLSearchParams({
    part: "snippet",
    q: `${query} recipe`,
    type: "video",
    maxResults: "10",
    key: apiKey,
  });

  const res = await fetch(
    `https://www.googleapis.com/youtube/v3/search?${params}`,
  );
  if (!res.ok) return [];
  const json = await res.json();
  const items = Array.isArray(json.items) ? json.items : [];

  return items.map((item: Record<string, unknown>): RecipeResult => {
    const id = item.id as Record<string, unknown>;
    const snippet = item.snippet as Record<string, unknown>;
    const thumbnails = snippet.thumbnails as Record<string, unknown>;
    const thumbnail = (thumbnails?.medium ?? thumbnails?.default) as
      | Record<string, unknown>
      | undefined;
    return {
      type: "video",
      title: String(snippet.title ?? ""),
      thumbnailUrl: String(thumbnail?.url ?? ""),
      url: `https://www.youtube.com/watch?v=${id.videoId}`,
      source: String(snippet.channelTitle ?? "YouTube"),
    };
  });
}

async function searchWeb(query: string): Promise<RecipeResult[]> {
  const apiKey = Deno.env.get("GOOGLE_CSE_KEY");
  const cx = Deno.env.get("GOOGLE_CSE_CX");
  if (!apiKey || !cx) return [];

  const params = new URLSearchParams({
    key: apiKey,
    cx,
    q: `${query} recipe`,
    num: "10",
  });

  const res = await fetch(
    `https://www.googleapis.com/customsearch/v1?${params}`,
  );
  if (!res.ok) return [];
  const json = await res.json();
  const items = Array.isArray(json.items) ? json.items : [];

  return items.map((item: Record<string, unknown>): RecipeResult => {
    const pagemap = item.pagemap as Record<string, unknown> | undefined;
    const cseThumbs = pagemap?.cse_thumbnail as
      | Array<Record<string, unknown>>
      | undefined;
    return {
      type: "web",
      title: String(item.title ?? ""),
      thumbnailUrl: String(cseThumbs?.[0]?.src ?? ""),
      url: String(item.link ?? ""),
      source: String(item.displayLink ?? ""),
    };
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { query } = await req.json();
    if (typeof query !== "string" || query.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "query is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const [videoResults, webResults] = await Promise.all([
      searchYouTube(query).catch(() => []),
      searchWeb(query).catch(() => []),
    ]);

    return new Response(
      JSON.stringify({ results: [...videoResults, ...webResults] }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (_err) {
    return new Response(JSON.stringify({ results: [] }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
