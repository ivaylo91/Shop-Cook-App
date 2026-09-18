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

/// The signed-in user making the call, or null.
///
/// The gateway's JWT check lets the publishable key through, and that key
/// ships inside the app for anyone to extract. Without this, anyone could
/// use this function without an account; so the caller must be a real
/// signed-in user, which only Supabase Auth can confirm.
async function signedInUser(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  try {
    const res = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
      headers: { Authorization: auth, apikey },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch {
    return null;
  }
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
  // IPv6 literals are refused outright: "::ffff:127.0.0.1" and friends
  // spell a private address in too many ways to list, and recipe sites are
  // reached by name.
  if (host.startsWith("[") || host.includes(":")) return false;
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
    /^0\./.test(host) ||
    /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(host)
  ) {
    return false;
  }
  return true;
}

const MAX_REDIRECTS = 5;

/// Fetches [url], following redirects by hand so every hop passes the same
/// public-address check as the first: with automatic following, a public
/// page could bounce the request on to a private one. Null when a hop is
/// refused or there are too many.
async function fetchPublic(url: string): Promise<Response | null> {
  let current = url;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    if (!isPubliclyFetchable(current)) return null;
    const res = await fetch(current, {
      headers: {
        // Plenty of recipe sites serve nothing useful to unknown agents.
        "User-Agent":
          "Mozilla/5.0 (compatible; ShopCookBot/1.0; +https://shopcook.app)",
        "Accept": "text/html,application/xhtml+xml",
      },
      redirect: "manual",
    });
    const location = res.headers.get("location");
    if (res.status < 300 || res.status >= 400 || !location) return res;
    await res.body?.cancel();
    current = new URL(location, current).toString();
  }
  return null;
}

/// The body as text, reading no more than [limit] bytes of it: a page
/// larger than that is cut rather than held in memory whole.
async function readCapped(res: Response, limit: number): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (size < limit) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    size += value.length;
  }
  await reader.cancel().catch(() => {});
  const all = new Uint8Array(Math.min(size, limit));
  let offset = 0;
  for (const chunk of chunks) {
    const part = chunk.subarray(0, all.length - offset);
    all.set(part, offset);
    offset += part.length;
    if (offset >= all.length) break;
  }
  return new TextDecoder().decode(all);
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
  image: string;
}

/// schema.org `image` may be a URL, a list of URLs, or ImageObjects.
function imagesOf(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) return value.flatMap(imagesOf);
  if (value && typeof value === "object") {
    const url = (value as Record<string, unknown>)["url"];
    return typeof url === "string" ? [url] : [];
  }
  return [];
}

/// The first usable picture: absolute, and https where one is offered —
/// Android will not load a plain http image. A page offering only http
/// gets it upgraded, which nearly every image host serves.
function pickImage(candidates: string[], pageUrl: string): string {
  const absolute = candidates
    .map((raw) => {
      try {
        return new URL(decodeEntities(raw.trim()), pageUrl).toString();
      } catch {
        return "";
      }
    })
    .filter((url) => /^https?:\/\//i.test(url));
  return absolute.find((url) => url.startsWith("https://")) ??
    absolute[0]?.replace(/^http:\/\//i, "https://") ?? "";
}

/// Open Graph and microdata images, for pages whose recipe data has none.
function pageImages(html: string): string[] {
  const found: string[] = [];
  for (
    const pattern of [
      /<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]*content=["']([^"']+)["']/gi,
      /<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:image["']/gi,
      /itemprop=["']image["'][^>]*(?:content|src)=["']([^"']+)["']/gi,
    ]
  ) {
    for (const match of html.matchAll(pattern)) found.push(match[1]);
  }
  return found;
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
    image: "",
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
    image: "",
  };
}

function parse(html: string, pageUrl: string): Parsed | null {
  const recipe = parseRecipe(html);
  if (!recipe) return null;
  const { images, ...parsed } = recipe;
  return {
    ...parsed,
    image: pickImage([...images, ...pageImages(html)], pageUrl),
  };
}

function parseRecipe(html: string): (Parsed & { images: string[] }) | null {
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
    if (result.ingredients.length > 0) {
      return { ...result, images: imagesOf(recipe["image"]) };
    }
  }

  const micro = fromMicrodata(html);
  return micro && micro.ingredients.length > 0 ? { ...micro, images: [] } : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (!(await signedInUser(req))) {
    return reply({ error: "Sign in to import recipes." }, 401);
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
    const res = await fetchPublic(url);
    if (!res) {
      return reply({
        ingredients: [],
        error: "That page redirects somewhere that is not a public web address.",
      });
    }
    if (!res.ok) {
      await res.body?.cancel();
      return reply({
        ingredients: [],
        error: `The site returned ${res.status}.`,
      });
    }
    html = await readCapped(res, MAX_BYTES);
  } catch (_err) {
    return reply({ ingredients: [], error: "Could not reach that page." });
  }

  const recipe = parse(html, url);
  if (!recipe) {
    return reply({
      ingredients: [],
      error: "No ingredient list found on that page.",
    });
  }
  return reply({ ...recipe });
});
