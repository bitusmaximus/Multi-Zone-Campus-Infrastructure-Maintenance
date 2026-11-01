# Supabase SMTP Setup — BDU University Email Verification

This guide configures Supabase to send OTP verification codes through BDU's university mail server
so that students receive the 6-digit code in their `@bdu.edu.et` inbox.

---

## Option A — Custom SMTP (Recommended)

### Step 1 · Get SMTP credentials from BDU IT
Ask Campus IT (or check with your system admin) for:

| Field | Typical BDU value | Where to get it |
|---|---|---|
| SMTP Host | `mail.bdu.edu.et` | IT department |
| SMTP Port | `587` (TLS) or `465` (SSL) | IT department |
| Username | `noreply@bdu.edu.et` | IT department |
| Password | (set by IT admin) | IT department |
| From address | `noreply@bdu.edu.et` | IT department |
| From name | `BDU Campus Maintenance` | Your choice |

### Step 2 · Configure in Supabase Dashboard

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard) → your project
2. Go to **Project Settings → Authentication**
3. Scroll to **SMTP Settings**
4. Toggle **Enable Custom SMTP** → ON
5. Fill in the fields from Step 1
6. Click **Save**

### Step 3 · Set email rate limits (free tier)

Still in **Project Settings → Authentication**:
- Set **Rate limit for sending emails** to match your IT policy (default 30/hour is fine)

### Step 4 · Customize the OTP email template (optional)

Go to **Authentication → Email Templates → Confirm signup**

Replace the body with something like:

```html
<h2>BDU Campus Maintenance — Email Verification</h2>
<p>Your 6-digit verification code is:</p>
<h1 style="letter-spacing:8px; font-size:36px;">{{ .Token }}</h1>
<p>This code expires in 10 minutes. Do not share it with anyone.</p>
<p>— BDU IT Systems</p>
```

---

## Option B — Supabase Edge Function (Advanced)

If BDU IT cannot provide SMTP credentials, you can send emails using BDU's webmail via an
Edge Function that calls the SMTP server programmatically.

### Deploy the edge function

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link your project
supabase link --project-ref <YOUR_PROJECT_REF>

# Deploy the email function
supabase functions deploy send-otp-email
```

The edge function source is at `backend/supabase/functions/send-otp-email/index.ts`

### Set environment secrets

```bash
supabase secrets set SMTP_HOST=mail.bdu.edu.et
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=noreply@bdu.edu.et
supabase secrets set SMTP_PASS=<password-from-IT>
supabase secrets set FROM_EMAIL=noreply@bdu.edu.et
```

---

## Option C — Google Workspace / Microsoft 365 (If BDU uses it)

If BDU uses Google Workspace (`@bdu.edu.et` hosted on Gmail):
- Use Gmail SMTP: `smtp.gmail.com`, port `587`
- Enable 2FA on the `noreply@bdu.edu.et` Google account
- Generate an **App Password** and use that as the SMTP password in Supabase
- No extra infrastructure needed

If BDU uses Microsoft 365:
- Use `smtp.office365.com`, port `587`
- Same App Password approach

---

## Verification Flow (already implemented in the app)

```
Student enters @bdu.edu.et email + password
        ↓
App calls supabase.auth.signUp()
        ↓
Supabase sends 6-digit OTP to student's BDU inbox
        ↓
Student opens BDU webmail → copies the code
        ↓
App shows OTP input screen
        ↓
Student enters code → App calls supabase.auth.verifyOTP()
        ↓
Account confirmed ✓ → Logged in
```

---

## Database-level email enforcement

The following constraints are already in `supabase_schema.sql` and migrations:
- `check_university_email_domain` — blocks non-`@bdu.edu.et` emails in `profiles` table
- `check_new_user_domain()` trigger — blocks signup at `auth.users` level for any non-BDU email

These run **even if the app is bypassed** (e.g., direct API calls).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| OTP email not received | Check spam folder; verify SMTP credentials in Supabase dashboard |
| "Email rate limit exceeded" | Upgrade Supabase plan or reduce test signups |
| SMTP connection refused | Try port 465 instead of 587; ask IT if TLS/SSL is required |
| Invalid OTP | Code expires in 10 min; use Resend button in app |
| Non-BDU email attempt | App blocks it before API call; DB trigger blocks it at backend |
