# arXiv Trend Advisor – Web App

This is the **web app** component. To run it, you need to serve the files from this folder. From the **project root**, go here with: `cd web_app`.

Static frontend for the arxiv-trend-predictor API. Enter a paper title (and optional abstract) to get domain classification, growth trend, and suggested keywords.

## Run locally

1. From the **project root**, go to the web app folder: `cd web_app`
2. Serve the files with any static server. Examples:

   **Python:**
   ```bash
   python -m http.server 8080
   ```

   **Node (npx):**
   ```bash
   npx serve -l 8080
   ```

3. Open **http://localhost:8080** in your browser. The app calls the live API at `https://eidon-api-001.onrender.com` by default.

## Use a different API URL

Set the base URL when serving the page by adding a `data-api-base` attribute on `<html>`:

```html
<html lang="en" data-api-base="http://localhost:8000">
```

Or run your backend on another host and point the attribute to that URL.

## Deploy on Render

Add a **Static Site** in the Render dashboard:

- **Build Command:** leave empty (static files only)
- **Publish Directory:** `web_app`
- **Root Directory:** project root (or leave blank if `web_app` is the repo root)

The frontend will call the API URL you deployed (e.g. `https://eidon-api-001.onrender.com`). No build step required.

Privacy policy URL (after deploy):

- `https://<your-static-site-domain>/privacy-policy.html`
- Use this URL in Google Play Console for the app privacy policy field.

## Files

- `index.html` – Form and result layout
- `privacy-policy.html` – Public privacy policy page for app store submission
- `styles.css` – Layout and theme
- `app.js` – Form submit, API call, result rendering
