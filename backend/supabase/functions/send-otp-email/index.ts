// Supabase Edge Function: send-otp-email
// Sends OTP verification emails via BDU university SMTP server
// Deploy: supabase functions deploy send-otp-email

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OtpEmailRequest {
  email: string;
  otp: string;
  type: "signup" | "recovery" | "email_change";
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, otp, type }: OtpEmailRequest = await req.json();

    // Enforce university email domain
    if (!email.endsWith("@bdu.edu.et") && !email.match(/@[a-z]+\.bdu\.edu\.et$/)) {
      return new Response(
        JSON.stringify({ error: "Only @bdu.edu.et email addresses are allowed" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // SMTP credentials from environment secrets
    const smtpHost = Deno.env.get("SMTP_HOST") ?? "mail.bdu.edu.et";
    const smtpPort = parseInt(Deno.env.get("SMTP_PORT") ?? "587");
    const smtpUser = Deno.env.get("SMTP_USER") ?? "noreply@bdu.edu.et";
    const smtpPass = Deno.env.get("SMTP_PASS") ?? "";
    const fromEmail = Deno.env.get("FROM_EMAIL") ?? "noreply@bdu.edu.et";

    const client = new SmtpClient();
    await client.connectTLS({
      hostname: smtpHost,
      port: smtpPort,
      username: smtpUser,
      password: smtpPass,
    });

    const subject =
      type === "signup"
        ? "BDU Campus Maintenance — Verify Your Email"
        : type === "recovery"
        ? "BDU Campus Maintenance — Password Reset Code"
        : "BDU Campus Maintenance — Email Change Code";

    const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #0a0a1a; color: #e0e0ff; margin: 0; padding: 0; }
    .container { max-width: 480px; margin: 40px auto; background: #12122a; border-radius: 16px; padding: 40px; border: 1px solid #2a2a5a; }
    .logo { text-align: center; font-size: 28px; margin-bottom: 8px; }
    .title { text-align: center; color: #00e5ff; font-size: 20px; margin-bottom: 32px; }
    .otp-box { text-align: center; background: #0d0d2b; border: 2px solid #00e5ff; border-radius: 12px; padding: 24px; margin: 24px 0; }
    .otp-code { font-size: 48px; font-weight: bold; letter-spacing: 16px; color: #00e5ff; font-family: monospace; }
    .note { color: #9090bb; font-size: 13px; text-align: center; margin-top: 16px; }
    .footer { color: #606090; font-size: 12px; text-align: center; margin-top: 32px; border-top: 1px solid #2a2a5a; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">🚀</div>
    <div class="title">BDU Campus Maintenance System</div>
    <p>Your verification code is:</p>
    <div class="otp-box">
      <div class="otp-code">${otp}</div>
    </div>
    <div class="note">
      ⏱ This code expires in <strong>10 minutes</strong>.<br>
      Do not share this code with anyone.
    </div>
    <div class="footer">
      Bahir Dar University — Campus Infrastructure Maintenance<br>
      This is an automated message. Do not reply.
    </div>
  </div>
</body>
</html>`;

    await client.send({
      from: `BDU Campus Maintenance <${fromEmail}>`,
      to: email,
      subject,
      html,
    });

    await client.close();

    return new Response(
      JSON.stringify({ success: true, message: `OTP sent to ${email}` }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("SMTP error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to send email", details: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
