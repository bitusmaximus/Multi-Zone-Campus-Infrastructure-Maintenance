# BDU University Email Setup — Microsoft 365 (Outlook)

Bahir Dar University provides all students and faculty with official university email accounts hosted on **Microsoft 365 (Exchange Online / Outlook)**:
- **Email format**: `name@bdu.edu.et`, `student_id@bdu.edu.et`, or `name@bit.bdu.edu.et`
- **Webmail Portal**: [https://outlook.office.com](https://outlook.office.com) or [https://portal.office.com](https://portal.office.com)
- **Mail Server Provider**: Microsoft 365 (Office 365)

Because BDU is powered by Microsoft 365, you have two zero-cost options to handle student authentication:

---

## Option 1 · Microsoft 365 SMTP Relay (Sends OTP to Outlook Inboxes)

Configure Supabase to deliver the 6-digit OTP codes directly through Microsoft 365's authenticated SMTP server.

### Step 1: Outlook SMTP Settings in Supabase

1. Open your project in the [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **Project Settings** → **Authentication** → **SMTP Settings**.
3. Toggle **Enable Custom SMTP** to **ON**.
4. Enter the standard Microsoft 365 SMTP parameters:

| Field | Value | Notes |
|---|---|---|
| **Sender Email** | `maintenance@bdu.edu.et` *(or any designated BDU Outlook account)* | Must be a licensed M365 mailbox |
| **Sender Name** | `BDU Campus Maintenance` | Display name shown to students |
| **SMTP Host** | `smtp.office365.com` | Official Microsoft 365 SMTP endpoint |
| **Port** | `587` | STARTTLS port |
| **Username** | `maintenance@bdu.edu.et` | Full BDU email address |
| **Password** | Account password or App Password | See note below on MFA |

5. Click **Save Changes**.

> [!TIP]
> **If 2-Step Verification (MFA) is enabled on the BDU account**:
> Standard passwords may be blocked by Microsoft Security Defaults. Create an **App Password**:
> 1. Sign in to [https://mysignins.microsoft.com/security-info](https://mysignins.microsoft.com/security-info).
> 2. Click **Add sign-in method** → select **App password**.
> 3. Name it `Supabase Maintenance Dispatch` and paste the 16-character code into the Supabase SMTP password field.

---

## Option 2 · "Sign In with BDU Outlook" (Microsoft Azure SSO — Recommended)

Because every BDU student already has a Microsoft account authenticated with Bahir Dar University, you can enable **Single Sign-On (SSO)** via Microsoft / Azure in Supabase.

### Advantages:
- ⚡ **No OTP delays**: Students tap "Sign in with BDU Outlook" and log in with their university Microsoft credentials.
- 🔒 **Zero spam folder issues**: Authentication happens directly through Microsoft's official login (`login.microsoftonline.com`).
- 🎓 **Strictly University-Only**: Restricts login to accounts belonging to the `@bdu.edu.et` domain.

### Setup in Supabase Dashboard:
1. In Supabase, go to **Authentication** → **Providers** → **Azure (Microsoft)**.
2. Toggle **Enable Azure** to **ON**.
3. Fill in:
   - **Azure Tenant URL**: `https://login.microsoftonline.com/organizations` (or BDU's specific Azure Tenant ID).
   - **Azure Client ID**: (from Azure App Registration).
   - **Azure Secret**: (from Azure App Registration).
4. Set the Callback URL in Azure to the URL provided by Supabase:
   `https://<YOUR_PROJECT_ID>.supabase.co/auth/v1/callback`

---

## How Students Verify Their Account (Current OTP Flow)

```
1. Student enters official Outlook address (e.g. abebe@bdu.edu.et)
                        ↓
2. Supabase sends 6-digit OTP code to student's Outlook mailbox
                        ↓
3. Student opens Outlook:
   • Mobile: Microsoft Outlook App (iOS / Android)
   • Web: https://outlook.office.com
                        ↓
4. Student copies 6-digit code and enters it in the Dispatch App
                        ↓
5. Account verified ✓ → Ready to submit maintenance reports
```

---

## Troubleshooting BDU Outlook Verification

| Issue | Cause | Solution |
|---|---|---|
| Email not arriving in Outlook | Clutter / Junk filter | Ask student to check the **"Junk Email"** or **"Other"** tab in Outlook. Mark sender as "Not Junk". |
| SMTP Error 535: Authentication unsuccessful | SMTP AUTH disabled on mailbox | In Microsoft 365 Admin Center: Users → Active Users → select user → Mail tab → Manage email apps → check **Authenticated SMTP**. |
| Non-BDU email rejected | University domain restriction | The app intentionally restricts registration to `@bdu.edu.et` and `@*.bdu.edu.et` domains. |
