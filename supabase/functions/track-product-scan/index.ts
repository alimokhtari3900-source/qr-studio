const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const rawLength = Number(request.headers.get("content-length") ?? "0");
  if (rawLength > 2048) {
    return jsonResponse(413, { error: "Request too large" });
  }

  try {
    const payload = await request.json();
    const productId = typeof payload?.product_id === "string"
      ? payload.product_id
      : "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(productId)) {
      return jsonResponse(400, { error: "Invalid product id" });
    }

    let referrerDomain: string | null = null;
    if (typeof payload?.referrer === "string" && payload.referrer.length <= 2048) {
      try {
        const parsed = new URL(payload.referrer);
        if (parsed.protocol === "https:" || parsed.protocol === "http:") {
          referrerDomain = parsed.hostname.slice(0, 120);
        }
      } catch {
        referrerDomain = null;
      }
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const secretMapRaw = Deno.env.get("SUPABASE_SECRET_KEYS");
    let secretKey = "";
    if (secretMapRaw) {
      try {
        const secretMap = JSON.parse(secretMapRaw);
        secretKey = typeof secretMap?.default === "string" ? secretMap.default : "";
      } catch {
        secretKey = "";
      }
    }
    secretKey ||= Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !secretKey) {
      console.error("Required server-side Supabase credentials are unavailable.");
      return jsonResponse(500, { error: "Scan service is not configured" });
    }

    const response = await fetch(
      `${supabaseUrl.replace(/\/+$/, "")}/rest/v1/rpc/record_product_scan`,
      {
        method: "POST",
        headers: {
          "apikey": secretKey,
          "Authorization": `Bearer ${secretKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          p_product_id: productId,
          p_referrer_domain: referrerDomain,
        }),
      },
    );

    if (!response.ok) {
      console.error("Scan recording failed with status:", response.status);
      return jsonResponse(502, { error: "Scan could not be recorded" });
    }

    const recorded = await response.json();
    return jsonResponse(200, { recorded: recorded === true });
  } catch (error) {
    console.error("Invalid scan request:", error instanceof Error ? error.message : "Unknown error");
    return jsonResponse(400, { error: "Invalid request" });
  }
});
