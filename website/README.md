# REDIMG Website & Privacy Policy (Google Play Store Ready)

This directory contains the complete static website (HTML + CSS) for **REDIMG**, including the mandatory **Google Play Store Privacy Policy**, landing page, and Terms of Service.

---

## 📁 Files Included

| File | Purpose |
|---|---|
| [`index.html`](file:///d:/RedImg/website/index.html) | Main Landing page showcasing app features, Rate Us button, and Play Store link |
| [`privacy-policy.html`](file:///d:/RedImg/website/privacy-policy.html) | **Official Google Play Privacy Policy** (Required for Play Console submission) |
| [`terms.html`](file:///d:/RedImg/website/terms.html) | Terms of Service webpage |
| [`style.css`](file:///d:/RedImg/website/style.css) | Ultra-lightweight, zero-dependency, dark/light responsive CSS |

---

## 🚀 How to Host This Website for Free (Takes 2 Minutes)

Google Play Console requires a publicly accessible HTTPS link (e.g. `https://yourname.github.io/...`). You can host these files 100% free using any of these services:

### Option 1: GitHub Pages (Recommended - Fastest & Free)
1. Push your repository to GitHub.
2. In GitHub, go to your repo **Settings** &rarr; **Pages**.
3. Under **Branch**, select `main` (or `master`) and set the folder to `/website` or `/docs` (or copy the contents of `website/` to root of a `gh-pages` branch).
4. Click **Save**.
5. Your privacy policy URL will be:
   ```
   https://<your-username>.github.io/<repo-name>/privacy-policy.html
   ```

### Option 2: Cloudflare Pages / Netlify / Vercel (Drag & Drop)
1. Go to [Netlify Drop](https://app.netlify.com/drop) or Cloudflare Pages.
2. Drag and drop the `website` folder.
3. You get an instant HTTPS URL, e.g.:
   ```
   https://redimg-tools.netlify.app/privacy-policy.html
   ```

---

## 📋 What to enter in Google Play Console

When submitting to Google Play Console:
1. Go to **Policy and programs** &rarr; **App content** &rarr; **Privacy policy**.
2. Paste your hosted privacy policy URL:
   `https://<your-hosted-domain>/privacy-policy.html`
3. Click **Save**.

---

## 🔗 Linking from App without Increasing App Size

Because `url_launcher` is already in the project, opening this website in the user's default browser or Chrome Custom Tab adds **0 KB** extra overhead (no heavy WebViews or embedded browsers):

```dart
// Example in settings_screen.dart:
onTap: () async {
  final url = Uri.parse('https://<your-hosted-domain>/privacy-policy.html');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
```
