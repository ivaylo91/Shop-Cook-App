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
/// Other languages' headings are here too: a description giving the list
/// again in Russian or German must start a new section for it, so that
/// only one of them is kept (see [inOneLanguage]).
const INGREDIENTS =
  /\b(ingredients?|you(?:'|’)?ll need|what you need|shopping list|zutaten|ingredientes|ingrédients|ingredienti)\b|(съставки|продукти|продукты|ингредиент|необходимо|нужно ви|ще ви трябва)/iu;

/// A short line that introduces the method.
const METHOD =
  /\b(method|instructions?|directions?|preparation|how to (?:make|cook)|steps?|zubereitung|preparación|préparation)\b|(приготвяне|приготовление|начин на|способ|стъпки|рецепта:)/iu;

/// Where a description stops being about the recipe.
const OFF_TOPIC =
  /(https?:\/\/|www\.|#[\p{L}\p{N}_]|^\d{1,2}:\d{2}\b|subscribe|instagram|facebook|tiktok|patreon|affiliate|sponsor|абонирайте|последвайте)/iu;

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

/// A line that opens a section of the kind [pattern] names: short, and
/// either set as a heading or free of amounts ("Ingredients", not
/// "2 steps back from the stove").
function opens(line: string, pattern: RegExp): boolean {
  const text = line.trim();
  return text.length > 0 && text.length <= 45 && pattern.test(text) &&
    !OFF_TOPIC.test(text) && (isHeading(text) || !/\d/.test(text));
}

/// A sub-heading written without a colon: "За заливката", "For the sauce".
const SUBHEADING = /^(за|for( the)?)\s+[^\d\s]+(\s+[^\d\s]+){0,2}$/iu;

/// How many it serves: "за 4 порции", "Serves 4".
const SERVINGS = /(порци|servings?\b|serves\b|makes\b)/iu;

/// A line in an ingredient list that is not an ingredient: a note in whole
/// sentences ("Баницата се пече на 180 градуса.", "Тавата е 32 см."), a
/// sub-heading, or the servings.
function isAside(text: string): boolean {
  if (SUBHEADING.test(text) || SERVINGS.test(text)) return true;
  const words = text.split(/\s+/).length;
  return !AMOUNT.test(text) && words >= 5 && /[.!?]$/.test(text);
}

/// The lines under a heading, until the next section starts: any
/// ingredients or method heading, since a second "Ingredients:" is usually
/// the same list again in another language. Other sub-headings ("For the
/// sauce:") are skipped; two blank lines in a row end it. In a [list] (the
/// ingredients, not the method), asides are skipped too.
function section(
  lines: string[],
  from: number,
  maxLength: number,
  list: boolean,
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
    if (opens(line, INGREDIENTS) || opens(line, METHOD)) break;
    if (isHeading(line)) continue;
    const text = clean(line);
    if (text.length < 2) continue;
    if (list && isAside(text)) continue;
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

type Script = "cyrillic" | "latin";

/// Which alphabet most of [text] is written in; null when it has letters
/// of neither (amounts alone, or another script entirely).
function scriptOf(text: string): Script | null {
  const cyrillic = text.match(/\p{Script=Cyrillic}/gu)?.length ?? 0;
  const latin = text.match(/\p{Script=Latin}/gu)?.length ?? 0;
  if (cyrillic === 0 && latin === 0) return null;
  return cyrillic >= latin ? "cyrillic" : "latin";
}

/// The alphabet a language code is written in.
export function scriptFor(language: string | undefined): Script | null {
  if (!language) return null;
  return /^(bg|ru|uk|sr|mk|be|kk)$/i.test(language) ? "cyrillic" : "latin";
}

/// One line with both languages on it ("1 кг картофи / 1 kg potatoes",
/// "Мляко (Milk)", "Brašno | Flour") cut down to the one in [script].
function oneLanguage(line: string, script: Script): string {
  const parts = line.split(/\s+\/\s+|\s*\|\s*/).filter((p) => p.trim());
  let text = line;
  if (parts.length > 1) {
    const kept = parts.filter((p) => scriptOf(p) !== otherThan(script));
    if (kept.length > 0) text = kept.join(" ");
  }
  // A translation in brackets after the name.
  const bare = text.replace(/\s*\(([^()]*)\)/g, (whole, inner: string) =>
    scriptOf(inner) === otherThan(script) ? "" : whole
  );
  return (scriptOf(bare) === script ? bare : text).replace(/\s+/g, " ").trim();
}

function otherThan(script: Script): Script {
  return script === "cyrillic" ? "latin" : "cyrillic";
}

type Language = "bg" | "ru" | "latin";

/// Bulgarian and Russian share an alphabet, so a list given in both is
/// told apart by the letters and endings only one of them uses.
function languageOf(text: string): Language | null {
  const script = scriptOf(text);
  if (script !== "cyrillic") return script;
  const russian = (text.match(
    /[ыэё]|[а-я](ого|его|ая|ый|ий)(?![а-я])|(?<![а-я])(для|по вкусу|меня|или по)(?![а-я])/giu,
  ) ?? []).length;
  const bulgarian = (text.match(
    /ъ|(?<![а-я])(със|аз|на вкус|може)(?![а-я])|[а-я](ът|та|то)(?![а-я])/giu,
  ) ?? []).length;
  return russian > bulgarian ? "ru" : "bg";
}

/// The language an app language code reads best in.
function languageFor(code: string | undefined): Language | null {
  if (!code) return null;
  if (/^(bg|sr|mk)$/i.test(code)) return "bg";
  if (/^(ru|uk|be|kk)$/i.test(code)) return "ru";
  return "latin";
}

/// When the description gives the list more than once, under a heading
/// each, and in different languages, keeps the sections in one of them.
function oneSectionLanguage(
  groups: string[][],
  preferred: Language | null,
  fallback: Language | null,
): string[] {
  const tagged = groups.map((g) => ({ lines: g, lang: languageOf(g.join(" ")) }));
  const present = new Set(tagged.map((t) => t.lang).filter(Boolean));
  if (present.size < 2) return groups.flat();
  const chosen = [preferred, fallback, tagged.find((t) => t.lang)?.lang]
    .find((l) => l != null && present.has(l));
  return tagged
    .filter((t) => t.lang === chosen || t.lang == null)
    .flatMap((t) => t.lines);
}

/// Many descriptions give the recipe twice, in the channel's language and
/// in English, and taking both put every product on the list twice. This
/// keeps one: [preferred] (the app's language) when the list has it,
/// otherwise [fallback] (the video title's), otherwise the first line's.
///
/// A few lines in the other alphabet are left alone — "Nutella" in a
/// Bulgarian list is an ingredient, not a translation. Only when a good
/// share of the list is in the other alphabet is it a second copy.
function inOneLanguage(
  lines: string[],
  preferred: Script | null,
  fallback: Script | null,
): string[] {
  const present = new Set(lines.map(scriptOf).filter(Boolean));
  if (present.size < 2) return lines;
  const script = [preferred, fallback, scriptOf(lines.find(scriptOf) ?? "")]
    .find((s): s is Script => s != null && present.has(s))!;

  const cut = lines.map((line) => oneLanguage(line, script));
  const foreign = cut.filter((line) => scriptOf(line) === otherThan(script));
  if (foreign.length < 2 || foreign.length < cut.length * 0.3) return cut;
  return cut.filter((line) => scriptOf(line) !== otherThan(script));
}

/// The line a photographed recipe is most likely titled with: the first
/// short line that is neither a heading nor an ingredient.
export function headline(text: string): string {
  for (const raw of text.split(/\r?\n/).slice(0, 8)) {
    const line = raw.trim();
    const letters = line.replace(/[^\p{L}]/gu, "").length;
    if (letters < 3 || line.length > 60) continue;
    if (opens(line, INGREDIENTS) || opens(line, METHOD)) return "";
    if (looksLikeIngredient(line) || OFF_TOPIC.test(line)) continue;
    return line.replace(/[:：]\s*$/, "");
  }
  return "";
}

export function fromDescription(
  description: string,
  options: { language?: string; title?: string } = {},
): { ingredients: string[]; steps: string[] } {
  const lines = description.split(/\r?\n/);
  // A title can be bilingual too ("Лозови сарми / Долма"); the channel's
  // own language comes first.
  const title = (options.title ?? "").split(/\s+[\/|]\s+/)[0];
  const preferred = scriptFor(options.language);
  const fallback = scriptOf(title);

  /// Every section under a heading of this kind: the sauce's own
  /// "Ingredients for the sauce:" belongs with the rest, but the same list
  /// again in Russian does not.
  const sections = (pattern: RegExp, maxLength: number, list: boolean) => {
    const seen = new Set<string>();
    const groups: string[][] = [];
    lines.forEach((line, i) => {
      if (!opens(line, pattern)) return;
      const group = section(lines, i + 1, maxLength, list)
        .filter((text) => !seen.has(text));
      group.forEach((text) => seen.add(text));
      if (group.length > 0) groups.push(group);
    });
    return oneSectionLanguage(
      groups,
      languageFor(options.language),
      languageOf(title),
    );
  };

  let ingredients = sections(INGREDIENTS, 90, true);

  // No heading, or nothing under it: the longest run of lines that look
  // like ingredients, if it is long enough to be a list and not chance.
  // One in the wanted language wins over a longer one in the other.
  if (ingredients.length === 0) {
    const runs: string[][] = [];
    let run: string[] = [];
    for (const raw of lines) {
      const line = raw.trim();
      if (line.length === 0) continue;
      if (looksLikeIngredient(line)) {
        run.push(clean(line));
      } else if (run.length > 0) {
        runs.push(run);
        run = [];
      }
    }
    if (run.length > 0) runs.push(run);
    const lists = runs.filter((r) => r.length >= 3);
    const wanted = preferred ?? fallback;
    const longest = (candidates: string[][]) =>
      candidates.reduce<string[]>(
        (best, r) => (r.length > best.length ? r : best),
        [],
      );
    const inWanted = longest(
      lists.filter((r) => wanted && scriptOf(r.join(" ")) === wanted),
    );
    ingredients = inWanted.length > 0 ? inWanted : longest(lists);
  }

  // A heading can name both ("Рецепта:"); its list is not a method.
  const steps = sections(METHOD, 600, false)
    .filter((s) => !ingredients.includes(s));

  return {
    ingredients: inOneLanguage(ingredients, preferred, fallback).slice(0, 60),
    steps: inOneLanguage(steps, preferred, fallback).slice(0, 40),
  };
}
