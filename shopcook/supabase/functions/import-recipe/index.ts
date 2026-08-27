// Supabase Edge Function: import-recipe
//
// Fetches a recipe page and pulls its ingredient list out of the
// schema.org/Recipe JSON-LD that nearly every recipe site publishes for
// Google. Runs server-side because the client cannot fetch arbitrary
// origins without hitting CORS.
//
// Needs no API keys, so this works even before search is configured.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const JSON_HEADERS = { ...corsHeaders, "Content-Type": "application/json" };

/// Cap on how much of a page we will read, so one enormous page cannot
/// exhaust the function's memory.
const MAX_BYTES = 2_000_000;

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

/// This function fetches a URL the caller supplies, so it must not be
/// usable as a proxy into private infrastructure.
function isPubliclyFetchable(raw: string): boolean {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return false;

  const host = url.hostname.toLowerCase();
  if (
    host === "localhost" ||
    host === "0.0.0.0" ||
    host.endsWith(".localhost") ||
    host.endsWith(".internal") ||
    host.endsWith(".local")
  ) {
    return false;
  }
  // Literal private / loopback / link-local addresses.
  if (
    /^127\./.test(host) ||
    /^10\./.test(host) ||
    /^192\.168\./.test(host) ||
    /^169\.254\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host) ||
    host === "::1" ||
    host.startsWith("fd") ||
    host.startsWith("fe80")
  ) {
    return false;
  }
  return true;
}

/// Walks JSON-LD (which may be a bare object, an array, or an @graph) and
/// returns the first node typed as a Recipe.
function findRecipe(node: unknown): Record<string, unknown> | null {
  if (Array.isArray(node)) {
    for (const item of node) {
      const found = findRecipe(item);
      if (found) return found;
    }
    return null;
  }
  if (node && typeof node === "object") {
    const obj = node as Record<string, unknown>;
    const declared = obj["@type"];
    const types = Array.isArray(declared) ? declared : [declared];
    if (
      types.some((t) => typeof t === "string" && t.toLowerCase() === "recipe")
    ) {
      return obj;
    }
    if (obj["@graph"]) return findRecipe(obj["@graph"]);
  }
  return null;
}

const ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
  "&apos;": "'",
  "&nbsp;": " ",
  "&frac12;": "½",
  "&frac14;": "¼",
  "&frac34;": "¾",
};

function decodeEntities(text: string): string {
  return text
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(
      /&(amp|lt|gt|quot|#39|apos|nbsp|frac12|frac14|frac34);/g,
      (match) => ENTITIES[match] ?? match,
    );
}

function textOf(value: unknown): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    if (typeof obj["name"] === "string") return obj["name"];
  }
  return "";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let url = "";
  try {
    ({ url } = await req.json());
  } catch {
    return reply({ error: "Send a JSON body with a url." }, 400);
  }

  if (typeof url !== "string" || !isPubliclyFetchable(url)) {
    return reply({ error: "That does not look like a public web address." }, 400);
  }

  let html: string;
  try {
    const res = await fetch(url, {
      headers: {
        // Plenty of recipe sites serve nothing useful to unknown agents.
        "User-Agent":
          "Mozilla/5.0 (compatible; ShopCookBot/1.0; +https://shopcook.app)",
        "Accept": "text/html,application/xhtml+xml",
      },
      redirect: "follow",
    });
    if (!res.ok) {
      return reply({
        ingredients: [],
        error: `The site returned ${res.status}.`,
      });
    }
    const buffer = await res.arrayBuffer();
    html = new TextDecoder().decode(buffer.slice(0, MAX_BYTES));
  } catch (_err) {
    return reply({ ingredients: [], error: "Could not reach that page." });
  }

  const blocks = [
    ...html.matchAll(
      /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
    ),
  ];

  for (const block of blocks) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(block[1].trim());
    } catch {
      continue; // Malformed block; try the next one.
    }

    const recipe = findRecipe(parsed);
    if (!recipe) continue;

    const rawList = recipe["recipeIngredient"] ?? recipe["ingredients"];
    const ingredients = (Array.isArray(rawList) ? rawList : [])
      .map(textOf)
      .map((line) => decodeEntities(line).replace(/\s+/g, " ").trim())
      .filter((line) => line.length > 0);

    if (ingredients.length === 0) continue;

    return reply({
      title: decodeEntities(textOf(recipe["name"])).trim(),
      ingredients,
    });
  }

  return reply({
    ingredients: [],
    error: "No ingredient list found on that page.",
  });
});
