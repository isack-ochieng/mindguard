# MindGuard Website

Static marketing and privacy site for MindGuard.

## Local development

```bash
cd website
npm install
npm run dev
```

## Production build

```bash
cd website
npm install
npm run build
```

Vite writes the production site to `website/dist`.

## Cloudflare Pages

Use the GitHub repository `isack-ochieng/mindguard` and configure:

- Production branch: `main`
- Root directory: `website`
- Build command: `npm run build`
- Build output directory: `dist`

The privacy policy is available at:

`https://mindguard.pages.dev/privacy`

The site is intentionally separate from the Flutter source tree so the mobile application build remains unaffected.
