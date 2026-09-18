// Supabase Edge Function: delete-account
//
// Deletes the calling user's account. Google Play requires apps that create
// accounts to let people delete them from inside the app.
//
// Only the auth user is deleted here: every cloud table references
// auth.users with ON DELETE CASCADE, so the user's lists, meals, products and
// recipes go with it. The app clears its own on-device copy afterwards.
//
// Uses SUPABASE_SERVICE_ROLE_KEY, which the Edge runtime provides and which
// never leaves the server.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function reply(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// The signed-in user making the call, or null. The account deleted is
/// always the caller's own: the id comes from their token, never the body.
async function signedInUser(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const apikey = req.headers.get("apikey") ??
    Deno.env.get("SUPABASE_ANON_KEY") ?? "";
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return reply({ error: "Use POST." }, 405);

  const userId = await signedInUser(req);
  if (!userId) return reply({ error: "Sign in to delete your account." }, 401);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) return reply({ error: "Not configured." }, 500);

  const res = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/auth/v1/admin/users/${userId}`,
    {
      method: "DELETE",
      headers: { Authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
    },
  );
  if (!res.ok) {
    return reply({ error: "The account could not be deleted." }, 502);
  }
  return reply({ deleted: true });
});
