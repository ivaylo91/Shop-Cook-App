// Reading a recipe out of a YouTube video.
//
// A video has no recipe data the way a recipe page does, but most cooking
// videos write the ingredients, and often the method, into their
// description. This finds them there: under an "Ingredients" heading when
// the description has one, otherwise as the longest run of lines that look
// like ingredients ("200 g flour", "- 2 eggs").
//
// Kept apart from index.ts, with no Deno-only APIs, so it can be tested on
// its own.

/// The video id in a YouTube link, or null when it is not one.
export function youtubeId(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const host = url.hostname.replace(/^(www|m|music)\./, "");
  let id: string | null = null;
  if (host === "youtu.be") {
    id = url.pathname.slice(1).split("/")[0];
  } else if (host === "youtube.com" || host === "youtube-nocookie.com") {
    if (url.pathname === "/watch") {
      id = url.searchParams.get("v");
    } else {
      const match = url.pathname.match(/^\/(?:shorts|embed|live|v)\/([^/?#]+)/);
      if (match) id = match[1];
    }
  }
  return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : null;
}

/// A short line that introduces the ingredients.
const INGREDIENTS =
  /\b(ingredients?|you(?:'|’)?ll need|what you need|shopping list)\b|(съставки|продукти|необходимо|нужно ви|ще ви трябва)/iu;

/// A short line that introduces the method.
const METHOD =
  /\b(method|instructions?|directions?|preparation|how to (?:make|cook)|steps?)\b|(приготвяне|начин на|стъпки|рецепта:)/iu;

/// Where a description stops being about the recipe.
const OFF_TOPIC =
  /(https?:\/\/|www\.|#\w|^\d{1,2}:\d{2}\b|subscribe|instagram|facebook|tiktok|patreon|affiliate|sponsor|абонирайте|последвайте)/iu;

/// A line that states an amount first, as ingredients do.
const AMOUNT =
  /^(?:\d+(?:[.,/]\d+)?|[½¼¾⅓⅔⅛]|a|an|one|two|three|half|pinch)\s*(?:-\s*\d+\s*)?(?:g|gr|kg|mg|ml|l|dl|cl|cups?|c\.|tbsp|tbs|tsp|oz|lb|lbs|pounds?|ounces?|grams?|cloves?|pinch|handful|slices?|pcs?|pieces?|cans?|sticks?|bunch|гр?\.?|кг|мл|л|ч\.?\s*ч\.?|с\.?\s*л\.?|к\.?\s*ч\.?|бр\.?|щипка|скилидк[аи]|глав[аи]|пакет[аи]?|кутия|връзк[аи])?\b/iu;

const BULLET = /^[-–—•*▪◦·●○■□✔✓☑➤►▶→🔸🔹🔶🔷✅]\s*/u;

/// A line reads as a heading: short, and either ends in a colon or is
/// written in capitals.
function isHeading(line: string): boolean {
  if (line.length === 0 || line.length > 45) return false;
  if (/[:：]\s*$/.test(line)) return true;
  const letters = line.replace(/[^\p{L}]/gu, "");
  return letters.length >= 3 && letters === letters.toUpperCase() &&
    letters !== letters.toLowerCase();
}

/// Removes bullets, numbering ("1.", "2)") and decorative symbols from the
/// start of a line, leaving amounts such as "1 cup" alone.
function clean(line: string): string {
  let text = line.trim().replace(BULLET, "");
  text = text.replace(/^\d+[.)]\s+(?=\D)/, "");
  text = text.replace(/^[^\p{L}\p{N}½¼¾⅓⅔⅛(]+/u, "");
  return text.replace(/\s+/g, " ").trim();
}

function looksLikeIngredient(line: string): boolean {
  const text = clean(line);
  if (text.length < 2 || text.length > 90) return false;
  if (OFF_TOPIC.test(text)) return false;
  return BULLET.test(line.trim()) || AMOUNT.test(text);
}

/// The lines under a heading, until the next section starts. Sub-headings
/// ("For the sauce:") are skipped; two blank lines in a row end it.
function section(
  lines: string[],
  from: number,
  stopAt: RegExp,
  maxLength: number,
): string[] {
  const out: string[] = [];
  let blanks = 0;
  for (let i = from; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.length === 0) {
      if (out.length > 0 && ++blanks >= 2) break;
      continue;
    }
    blanks = 0;
    if (OFF_TOPIC.test(line)) break;
    if (isHeading(line) && stopAt.test(line)) break;
    if (isHeading(line)) continue;
    const text = clean(line);
    if (text.length < 2) continue;
    if (text.length > maxLength) break;
    out.push(text);
  }
  return out;
}

/// Sites a link in a description points to that are never the recipe.
const NOT_RECIPES =
  /(?:^|\.)(youtube\.com|youtu\.be|instagram\.com|facebook\.com|fb\.me|tiktok\.com|twitter\.com|x\.com|patreon\.com|amazon\.|amzn\.|bit\.ly|linktr\.ee|pinterest\.|spotify\.com|discord\.|threads\.net|paypal\.|ko-fi\.com)/i;

/// Links in a description that may lead to the written recipe, as many
/// channels keep it on their own site. In order of appearance, at most
/// [limit].
export function recipeLinks(description: string, limit = 2): string[] {
  const out: string[] = [];
  for (const match of description.matchAll(/https?:\/\/[^\s<>"')\]]+/g)) {
    const link = match[0].replace(/[.,;:!?]+$/, "");
    let host: string;
    try {
      host = new URL(link).hostname;
    } catch {
      continue;
    }
    if (NOT_RECIPES.test(host) || out.includes(link)) continue;
    out.push(link);
    if (out.length >= limit) break;
  }
  return out;
}

export function fromDescription(
  description: string,
): { ingredients: string[]; steps: string[] } {
  const lines = description.split(/\r?\n/);
  const heading = (pattern: RegExp) =>
    lines.findIndex((l) => {
      const line = l.trim();
      return line.length > 0 && line.length <= 45 && pattern.test(line) &&
        !OFF_TOPIC.test(line);
    });

  let ingredients: string[] = [];
  const start = heading(INGREDIENTS);
  if (start >= 0) {
    ingredients = section(lines, start + 1, METHOD, 90);
  }

  // No heading, or nothing under it: the longest run of lines that look
  // like ingredients, if it is long enough to be a list and not chance.
  if (ingredients.length === 0) {
    let run: string[] = [];
    let best: string[] = [];
    for (const raw of lines) {
      const line = raw.trim();
      if (line.length === 0) continue;
      if (looksLikeIngredient(line)) {
        run.push(clean(line));
        if (run.length > best.length) best = run;
      } else {
        run = [];
      }
    }
    if (best.length >= 3) ingredients = best;
  }

  const methodStart = heading(METHOD);
  const steps = methodStart >= 0 && methodStart !== start
    ? section(lines, methodStart + 1, INGREDIENTS, 600)
    : [];

  return {
    ingredients: ingredients.slice(0, 60),
    steps: steps.slice(0, 40),
  };
}
