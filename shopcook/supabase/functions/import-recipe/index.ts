// Supabase Edge Function: import-recipe
//
// Fetches a recipe page and pulls its ingredients, method, servings and
// time out of the schema.org/Recipe data that nearly every recipe site
// publishes for Google — JSON-LD first, microdata as a fallback. Runs
// server-side because the client cannot fetch arbitrary origins without
// hitting CORS.
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
  "&apos;": "'",
  "&nbsp;": " ",
  "&bull;": "•",
  "&ndash;": "–",
  "&mdash;": "—",
  "&deg;": "°",
  "&frac12;": "½",
  "&frac14;": "¼",
  "&frac34;": "¾",
};

function decodeEntities(text: string): string {
  return text
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(
      /&#x([0-9a-f]+);/gi,
      (_, hex) => String.fromCodePoint(parseInt(hex, 16)),
    )
    .replace(/&[a-z0-9]+;/gi, (match) => ENTITIES[match.toLowerCase()] ?? match);
}

/// Markup to plain text. Block-level breaks become newlines so a method
/// written as one element with <br>s can still be split into steps.
function plainText(html: string): string {
  return decodeEntities(
    html
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/(p|li|div|h\d)>/gi, "\n")
      .replace(/<[^>]+>/g, ""),
  );
}

function tidy(line: string): string {
  return line
    .replace(/[ \t ]+/g, " ")
    // Sites decorate list items with a bullet in the text itself.
    .replace(/^[\s•·*–-]+/, "")
    .trim();
}

function textOf(value: unknown): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    if (typeof obj["name"] === "string") return obj["name"];
  }
  return "";
}

/// A step longer than this, arriving as unstructured prose, is broken into
/// sentences: in cooking mode one step is one screen, and a whole method on
/// one screen is no help with floury hands.
const LONG_STEP = 220;

function splitProse(text: string): string[] {
  const lines = plainText(text).split(/\n+/).map(tidy).filter(Boolean);
  const out: string[] = [];
  for (const line of lines) {
    if (line.length <= LONG_STEP) {
      out.push(line);
      continue;
    }
    // Sentence ends followed by a capital (Latin or Cyrillic) or digit, so
    // abbreviations such as "ч. л." or "tsp. salt" stay intact.
    out.push(
      ...line
        .split(/(?<=[.!?])\s+(?=[A-ZА-ЯЁ0-9])/u)
        .map(tidy)
        .filter(Boolean),
    );
  }
  return out;
}

/// schema.org lets recipeInstructions be a string, a list of strings, a
/// list of HowToSteps, or HowToSections that contain HowToSteps.
function stepsOf(value: unknown): string[] {
  if (typeof value === "string") return splitProse(value);
  if (Array.isArray(value)) return value.flatMap(stepsOf);
  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    if (obj["itemListElement"]) return stepsOf(obj["itemListElement"]);
    if (typeof obj["text"] === "string") return splitProse(obj["text"]);
    if (typeof obj["name"] === "string") return splitProse(obj["name"]);
  }
  return [];
}

/// ISO 8601 duration ("PT1H30M") to minutes; 0 when absent or unreadable.
function minutesOf(value: unknown): number {
  if (typeof value !== "string") return 0;
  const match = value.match(
    /^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i,
  );
  if (!match) return 0;
  const [, d, h, m] = match;
  return Number(d ?? 0) * 1440 + Number(h ?? 0) * 60 + Number(m ?? 0);
}

function servingsOf(value: unknown): string {
  const raw = Array.isArray(value) ? value[0] : value;
  if (typeof raw === "number") return String(raw);
  return typeof raw === "string" ? tidy(plainText(raw)) : "";
}

interface Parsed {
  title: string;
  ingredients: string[];
  steps: string[];
  servings: string;
  minutes: number;
}

function fromJsonLd(recipe: Record<string, unknown>): Parsed {
  const rawList = recipe["recipeIngredient"] ?? recipe["ingredients"];
  const total = minutesOf(recipe["totalTime"]);
  return {
    title: tidy(plainText(textOf(recipe["name"]))),
    ingredients: (Array.isArray(rawList) ? rawList : [])
      .map((line) => tidy(plainText(textOf(line))))
      .filter((line) => line.length > 0),
    steps: stepsOf(recipe["recipeInstructions"]),
    servings: servingsOf(recipe["recipeYield"]),
    minutes: total ||
      minutesOf(recipe["prepTime"]) + minutesOf(recipe["cookTime"]),
  };
}

/// Inner HTML of every element carrying the given itemprop. Not a real
/// parser: it pairs an opening tag with the next closing tag of the same
/// name, which is enough for the <li>s and <div>s recipe sites use.
function itemprops(html: string, name: string): string[] {
  const pattern = new RegExp(
    `<(\\w+)[^>]*\\bitemprop=["']${name}["'][^>]*>([\\s\\S]*?)</\\1>`,
    "gi",
  );
  return [...html.matchAll(pattern)].map((m) => m[2]);
}

/// Older sites (receptite.com among them) mark recipes up with microdata
/// attributes instead of a JSON-LD block.
function fromMicrodata(html: string): Parsed | null {
  if (!/itemtype=["']https?:\/\/schema\.org\/Recipe["']/i.test(html)) {
    return null;
  }
  const ingredients = [
    ...itemprops(html, "recipeIngredient"),
    ...itemprops(html, "ingredients"),
  ]
    .map((line) => tidy(plainText(line)))
    .filter(Boolean);

  const yieldMeta = html.match(
    /itemprop=["']recipeYield["'][^>]*content=["']([^"']+)["']/i,
  );

  return {
    title: tidy(plainText(itemprops(html, "name")[0] ?? "")),
    ingredients,
    steps: itemprops(html, "recipeInstructions").flatMap(splitProse),
    servings: yieldMeta
      ? tidy(yieldMeta[1])
      : tidy(plainText(itemprops(html, "recipeYield")[0] ?? "")),
    minutes: 0,
  };
}

function parse(html: string): Parsed | null {
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
    const result = fromJsonLd(recipe);
    if (result.ingredients.length > 0) return result;
  }

  const micro = fromMicrodata(html);
  return micro && micro.ingredients.length > 0 ? micro : null;
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

  const recipe = parse(html);
  if (!recipe) {
    return reply({
      ingredients: [],
      error: "No ingredient list found on that page.",
    });
  }
  return reply({ ...recipe });
});
