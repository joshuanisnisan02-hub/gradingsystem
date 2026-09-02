import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization) return json({ error: "Authentication required." }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const adminClient = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: authData, error: authError } = await callerClient.auth.getUser();
  if (authError || !authData.user) return json({ error: "Invalid session." }, 401);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "Invalid request body." }, 400);
  }

  if (body.action === "completePasswordChange") {
    const { error } = await adminClient
      .from("profiles")
      .update({ must_change_password: false, updated_at: new Date().toISOString() })
      .eq("id", authData.user.id);
    return error ? json({ error: error.message }, 400) : json({ ok: true });
  }

  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("role, is_active")
    .eq("id", authData.user.id)
    .single();
  if (profileError || profile?.role !== "administrator" || profile?.is_active === false) {
    return json({ error: "Administrator access required." }, 403);
  }

  if (body.action === "list") {
    const { data: authUsers, error: listError } = await adminClient.auth.admin.listUsers({ perPage: 1000 });
    if (listError) return json({ error: listError.message }, 400);
    const { data: profiles, error: profilesError } = await adminClient
      .from("profiles")
      .select("id, full_name, role, must_change_password, is_active");
    if (profilesError) return json({ error: profilesError.message }, 400);
    const profilesById = new Map((profiles ?? []).map((item) => [item.id, item]));
    return json({
      users: authUsers.users.map((user) => ({
        id: user.id,
        email: user.email,
        full_name: profilesById.get(user.id)?.full_name ?? user.user_metadata?.full_name ?? "",
        role: profilesById.get(user.id)?.role ?? "teacher",
        must_change_password: profilesById.get(user.id)?.must_change_password ?? false,
        is_active: profilesById.get(user.id)?.is_active ?? true,
      })),
    });
  }

  if (body.action === "create") {
    const email = String(body.email ?? "").trim().toLowerCase();
    const fullName = String(body.fullName ?? "").trim();
    const password = String(body.password ?? "");
    const role = String(body.role ?? "teacher");
    if (!email.includes("@") || !fullName || password.length < 8) {
      return json({ error: "A name, valid email, and temporary password of at least 8 characters are required." }, 400);
    }
    if (!["administrator", "teacher", "encoder"].includes(role)) {
      return json({ error: "Invalid role." }, 400);
    }

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
      app_metadata: { role },
    });
    if (createError || !created.user) return json({ error: createError?.message ?? "User creation failed." }, 400);

    const { error: profileUpsertError } = await adminClient.from("profiles").upsert({
      id: created.user.id,
      full_name: fullName,
      role,
      must_change_password: true,
      is_active: true,
      updated_at: new Date().toISOString(),
    });
    if (profileUpsertError) {
      await adminClient.auth.admin.deleteUser(created.user.id);
      return json({ error: profileUpsertError.message }, 400);
    }
    return json({ ok: true, id: created.user.id }, 201);
  }

  return json({ error: "Unknown action." }, 400);
});
