# Netlify deploy files

This directory contains files copied into the generated Netlify publish directory by `scripts/build_netlify_site.py`.

- `_headers`: production response security headers.

Do not put secrets here. Everything copied into `_site/` becomes publicly accessible after deployment.
