import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { AwsClient } from "https://deno.land/x/aws_api@v0.8.1/client/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Verify User Authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized user token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Parse request body
    const { filename, contentType, fileSizeBytes } = await req.json();
    if (!filename || !contentType) {
      return new Response(JSON.stringify({ error: "filename and contentType are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Enforce 100 MB maximum file size limit (SRS REQ-VLT-01)
    if (fileSizeBytes && fileSizeBytes > 100 * 1024 * 1024) {
      return new Response(JSON.stringify({ error: "File size exceeds 100 MB limit" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Construct unique storage path
    const sanitizedName = filename.replace(/[^a-zA-Z0-9.-]/g, "_");
    const uniqueStoragePath = `vault/${user.id}/${crypto.randomUUID()}-${sanitizedName}`;

    // 5. Cloudflare R2 Credentials
    const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "";
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
    const bucketName = Deno.env.get("R2_BUCKET_NAME") ?? "synchrobeat-vault";

    const r2Client = new AwsClient({
      accessKeyId,
      secretAccessKey,
      service: "s3",
      region: "auto",
    });

    const endpoint = `https://${accountId}.r2.cloudflarestorage.com/${bucketName}/${uniqueStoragePath}`;

    // Sign a presigned PUT request with 15 minutes (900 seconds) expiration
    const presignedUrl = await r2Client.sign(endpoint, {
      method: "PUT",
      headers: {
        "Content-Type": contentType,
      },
      aws: {
        signQuery: true,
      },
    });

    return new Response(
      JSON.stringify({
        uploadUrl: presignedUrl.url,
        storagePath: uniqueStoragePath,
        expiresInSeconds: 900,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
