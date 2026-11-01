# Option C — Free Gmail SMTP Relay for OTP Emails

Since BDU manages its own mail server (access requires IT credentials), this option lets you
send OTP verification codes via a **free Gmail account** as the SMTP relay — no IT department needed.

Students will receive a code from e.g. `bdu.campus.maintenance@gmail.com` but the email still
arrives in their `@bdu.edu.et` inbox and the app still enforces university email login.

---

## Step 1 — Create a Gmail account for the app

1. Go to [https://accounts.google.com/signup](https://accounts.google.com/signup)
2. Create an account like `bdu.campus.maintenance@gmail.com`
3. Enable **2-Step Verification** on that Google account:
   - [https://myaccount.google.com/security](https://myaccount.google.com/security) → 2-Step Verification → Turn On

---

## Step 2 — Generate a Gmail App Password

> [!IMPORTANT]
> You must have 2-Step Verification ON before App Passwords appear.

1. Go to [https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. App name: `BDU Campus Maintenance`
3. Click **Create**
4. Copy the 16-character password (e.g. `abcd efgh ijkl mnop`) — you only see it once

---

## Step 3 — Configure Supabase Custom SMTP

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard) → your project
2. Go to **Project Settings → Authentication**
3. Scroll to **SMTP Settings** → toggle **Enable Custom SMTP** → ON
4. Fill in:

| Field | Value |
|---|---|
| **SMTP Host** | `smtp.gmail.com` |
| **SMTP Port** | `587` |
| **Username** | `bdu.campus.maintenance@gmail.com` |
| **Password** | (the 16-char App Password from Step 2) |
| **Sender email** | `bdu.campus.maintenance@gmail.com` |
| **Sender name** | `BDU Campus Maintenance` |

5. Click **Save**

---

## Step 4 — Customize the OTP Email Template

In Supabase Dashboard → **Authentication → Email Templates → Confirm signup**, paste:

```html
<div style="font-family:Arial,sans-serif;background:#0a0a1a;color:#e0e0ff;padding:40px;border-radius:16px;max-width:480px;margin:auto">
  <div style="text-align:center;font-size:32px">🚀</div>
  <h2 style="text-align:center;color:#00e5ff">BDU Campus Maintenance</h2>
  <p>Your email verification code is:</p>
  <div style="text-align:center;background:#0d0d2b;border:2px solid #00e5ff;border-radius:12px;padding:24px;margin:24px 0">
    <span style="font-size:48px;font-weight:bold;letter-spacing:16px;color:#00e5ff;font-family:monospace">{{ .Token }}</span>
  </div>
  <p style="color:#9090bb;font-size:13px;text-align:center">⏱ Expires in <strong>10 minutes</strong>. Do not share this code.</p>
  <hr style="border-color:#2a2a5a;margin-top:32px">
  <p style="color:#606090;font-size:12px;text-align:center">Bahir Dar University — Campus Infrastructure Maintenance<br>Automated message. Do not reply.</p>
</div>
```

---

## Step 5 — Test it

1. Open the app at `http://YOUR_IP:8080`
2. Register with your `@bdu.edu.et` email
3. Check your BDU inbox — the code arrives from `bdu.campus.maintenance@gmail.com`
4. Enter the 6-digit code in the app → verified ✓

---

## Limits (Gmail free tier)

| Limit | Value |
|---|---|
| Emails per day | 500 |
| Emails per hour | ~100 |
| Cost | **Free** |

500/day is more than enough for a university campus system.

---

## Future upgrade path

When BDU IT provides official SMTP credentials, just swap in:
- Host: `mail.bdu.edu.et`
- From: `noreply@bdu.edu.et`

No app code changes needed — only the Supabase dashboard SMTP settings change.
