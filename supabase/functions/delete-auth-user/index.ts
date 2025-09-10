// deno.jsonc’da import map ayarlı varsayımı
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Auth check: JWT al
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Kimlik doğrulama (user token'ı ile gelmeli)
    const { data: { user }, error: getUserErr } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (getUserErr || !user) {
      return new Response(JSON.stringify({ ok: false, error: "AUTH_REQUIRED" }), { status: 401 });
    }

    // Son bir kontrol: request_account_deletion RPC gerçekten çağrılmış mı? (opsiyonel)
    // Basit tutuyoruz: direkt sil
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) {
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 400 });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});