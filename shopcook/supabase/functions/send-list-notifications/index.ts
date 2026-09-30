// Supabase Edge Function: send-list-notifications
//
// Tells the other members of a shared list what someone changed: "Ben added
// Milk" as a notification, when their app is closed. Called once a minute by
// a database job (see the list_notifications migration), and only when there
// is something waiting.
//
// It takes no input and returns only counts, so calling it from outside
// does nothing the job would not do a moment later: it sends what is due.
// What is due is decided in the database (claim_list_activity), which hands
// each entry over exactly once, so overlapping calls cannot double-send.
//
// Needs the FIREBASE_SERVICE_ACCOUNT secret — the service account key file
// from Firebase, as JSON — to be allowed to send through Firebase Cloud
// Messaging. SUPABASE_SERVICE_ROLE_KEY is provided by the Edge runtime.

type Activity = {
  list_id: string;
  list_name: string;
  actor_id: string;
  actor_name: string;
  added: number;
  added_names: string[];
  changed: number;
  notify: boolean;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const url = () => Deno.env.get("SUPABASE_URL") ?? "";

function serviceHeaders(): Record<string, string> {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return {
    Authorization: `Bearer ${key}`,
    apikey: key,
    "Content-Type": "application/json",
  };
}

function base64Url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/// The key file as pasted into the secret. Also accepts its contents
/// without the outer braces, which is what selecting "everything inside"
/// in an editor copies.
function readAccount(raw: string): ServiceAccount | null {
  const text = raw.trim();
  for (const candidate of [text, `{${text.replace(/,\s*$/, "")}}`]) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed?.private_key && parsed?.client_email && parsed?.project_id) {
        return parsed as ServiceAccount;
      }
    } catch {
      // Not this shape; try the next.
    }
  }
  return null;
}

/// An access token for Firebase Cloud Messaging, from the service account:
/// a short-lived statement signed with its private key, exchanged with
/// Google for a token.
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 600,
  };
  const unsigned = `${base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${
    base64Url(JSON.stringify(claims))
  }`;

  const pem = account.private_key
    .replace(/-----[A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64Url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`token exchange failed: ${res.status}`);
  return (await res.json()).access_token as string;
}

/// The sentence for one entry, in the recipient's language. The list's name
/// is the notification's title, so it is not repeated here.
function message(entry: Activity, lang: string): string {
  const bg = lang === "bg";
  const who = entry.actor_name || (bg ? "Някой" : "Someone");
  const names = entry.added_names.filter((n) => n);

  if (entry.added === 1 && names.length === 1) {
    return bg ? `${who} добави ${names[0]}` : `${who} added ${names[0]}`;
  }
  if (entry.added > 1) {
    const listed = names.join(", ") + (entry.added > names.length ? "…" : "");
    return bg
      ? `${who} добави ${entry.added} продукта: ${listed}`
      : `${who} added ${entry.added} items: ${listed}`;
  }
  return bg ? `${who} промени списъка` : `${who} updated the list`;
}

/// Everyone on the list but the person who made the change, as the phones
/// they can be reached on.
async function recipients(
  entry: Activity,
): Promise<{ token: string; lang: string }[]> {
  const members = await fetch(
    `${url()}/rest/v1/shared_list_members?select=user_id&list_id=eq.${entry.list_id}&user_id=neq.${entry.actor_id}`,
    { headers: serviceHeaders() },
  );
  if (!members.ok) return [];
  const ids = ((await members.json()) as { user_id: string }[])
    .map((m) => m.user_id);
  if (ids.length === 0) return [];

  const tokens = await fetch(
    `${url()}/rest/v1/device_tokens?select=token,lang&user_id=in.(${ids.join(",")})`,
    { headers: serviceHeaders() },
  );
  return tokens.ok ? await tokens.json() : [];
}

/// Sends one notification. Returns false when the phone is gone — the app
/// was uninstalled, or its token replaced — so the token can be forgotten.
async function send(
  account: ServiceAccount,
  bearer: string,
  token: string,
  entry: Activity,
  lang: string,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${bearer}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: entry.list_name, body: message(entry, lang) },
          data: { list_id: entry.list_id },
          android: {
            // One notification per list: a newer one replaces the last
            // rather than stacking up beside it.
            notification: { tag: entry.list_id, channel_id: "shared_lists" },
          },
        },
      }),
    },
  );
  return res.status !== 404 && res.status !== 400;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) {
    return reply({ error: "The FIREBASE_SERVICE_ACCOUNT secret is not set." }, 503);
  }
  const account = readAccount(raw);
  if (!account) {
    return reply({
      error: "The FIREBASE_SERVICE_ACCOUNT secret is not the key file's JSON.",
    }, 503);
  }

  // Checked before anything is claimed: entries are removed as they are
  // handed over, and must not be taken if they cannot then be sent.
  let bearer: string;
  try {
    bearer = await accessToken(account);
  } catch {
    return reply({ error: "Could not reach Firebase." }, 502);
  }

  const claimed = await fetch(`${url()}/rest/v1/rpc/claim_list_activity`, {
    method: "POST",
    headers: serviceHeaders(),
    body: "{}",
  });
  if (!claimed.ok) return reply({ error: "Could not read activity." }, 500);
  const entries = (await claimed.json()) as Activity[];

  let sent = 0;
  const gone: string[] = [];
  for (const entry of entries) {
    if (!entry.notify) continue;
    for (const { token, lang } of await recipients(entry)) {
      if (await send(account, bearer, token, entry, lang)) sent++;
      else gone.push(token);
    }
  }

  for (const token of gone) {
    await fetch(
      `${url()}/rest/v1/device_tokens?token=eq.${encodeURIComponent(token)}`,
      { method: "DELETE", headers: serviceHeaders() },
    );
  }

  return reply({ entries: entries.length, sent, forgotten: gone.length });
});
