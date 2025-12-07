# Project Context: Docker + WordPress + Vite + Theme

This document provides a concise, authoritative overview to give AI prompts clear context about the repository’s architecture, runtime, and conventions. It covers Docker services, how they connect to WordPress and the active theme, asset compilation via Vite, class structure, documentation guidelines, and Composer autoload.

## Stack Overview
- Docker Compose orchestrates services: `wordpress`, `php` (PHP-FPM), `nginx` (optional reverse proxy), `db` (MySQL 8), and `vite` (Node 18 for assets dev/build).
- WordPress runs in its own container and loads the active theme from a mounted folder.
- Front-end assets (JS/SCSS) are compiled with Vite (development server + production builds).
- PHP classes in the theme are autoloaded via Composer `vendor/autoload.php` using classmap.

## Docker Services
File: `docker-compose.yaml`

- `wordpress`
  - Build context: `docker/wordpress/Dockerfile`
  - Ports: `${WP_PORT}:80` (from `.env`)
  - Environment: `ACTIVE_THEME`, `WORDPRESS_DB_*`, `VITE_PORT`, `WP_ENV`, `PREFIX`
  - Volumes:
    - WordPress core: `wordpress_data:/var/www/html`
    - Theme mount: `./themes/${ACTIVE_THEME}:/var/www/html/wp-content/themes/${ACTIVE_THEME}`
  - Entrypoint pre-tasks: `docker/scripts/wp-entrypoint.sh` installs required plugins (WP‑CLI) and runs Composer install for active theme when `composer.json` exists.

- `php` (PHP-FPM)
  - Image: `php:8.1-fpm`
  - Shares the active theme volume for PHP execution.

- `nginx` (optional)
  - Serves via `${NGINX_PORT}:80`, proxies PHP to `php:9000`, uses `nginx.conf` from project root.

- `db` (MySQL 8.0)
  - Ports: `${MYSQL_PORT}:3306`
  - Env: `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`
  - Volume: `db_data:/var/lib/mysql`

- `vite` (Node 18)
  - Working dir: `/app`
  - User: `1000:1000` (non-root)
  - Volumes:
    - `./themes/${ACTIVE_THEME}/assets:/app`
    - `./themes/${ACTIVE_THEME}/blocks:/app/blocks` (so block definitions/styles are available)
  - Command (dev): `npm install && npm run dev`
  - Ports: `${VITE_PORT}:${VITE_PORT}`

## Environment (.env)
Key variables:
```
ACTIVE_THEME=travel-concierge-me-theme
WP_PORT=5050
NGINX_PORT=5000
VITE_PORT=5159
MYSQL_PORT=5309
WORDPRESS_DB_HOST=db
WORDPRESS_DB_USER=…
WORDPRESS_DB_PASSWORD=…
WORDPRESS_DB_NAME=…
MYSQL_ROOT_PASSWORD=…
WP_ENV=development
PREFIX=tcm_
```

## Theme Location and Runtime
- Theme path (host): `themes/travel-concierge-me-theme/`
- Theme path (in `wordpress` container): `/var/www/html/wp-content/themes/travel-concierge-me-theme`
- `functions.php` loads environment config (`inc/env.php`) and the Composer-first bootstrap (`inc/loader.php`).
- `inc/loader.php` loads `vendor/autoload.php` and helper functions, and registers WP‑CLI commands when in WP‑CLI context.
- `classes/Admin/Admin.php` bootstraps the theme lifecycle (hooks, menus, enqueue, DB migrations, REST, blocks manager).

## Composer Autoload (vendor)
- Theme includes `composer.json` with classmap autoload for `classes/`.
- On container startup (`wp-entrypoint.sh`), Composer runs in the active theme if `composer.json` exists:
  - `composer install --no-dev --optimize-autoloader -d /var/www/html/wp-content/themes/${ACTIVE_THEME}`
- Theme PHP files should reference Composer autoloader via `inc/loader.php` (which requires `vendor/autoload.php`).
- To refresh autoload after class changes:
  - `docker compose exec wordpress bash -lc 'cd /var/www/html/wp-content/themes/$ACTIVE_THEME && composer dump-autoload -o'`

## Classes Architecture (Theme)
Folder: `themes/travel-concierge-me-theme/classes/`
- `Admin/` → `Admin.php`, `Enqueue.php`
  - `Admin` (Singleton) registers theme hooks and instantiates subsystems.
  - `Enqueue` registers assets for admin/front/editor and integrates with `tcm_get_asset`.
- `Base/` → `Base.php`
  - Provides lifecycle (`init()`, `register_actions()`, `register_filters()`), hook helpers, and composes traits.
- `Blocks/` → `BlocksManager.php`
  - Registers Gutenberg custom blocks, render callbacks, and block categories.
- `Database/` → migrations/table managers, `CliMigration.php` for WP‑CLI (`my-wp-tables-migrate`).
- `Endpoints/` → REST endpoints (e.g., FormsEntries).
- `PostTypes/`, `Taxonomies/`, `Traits/` → CPT/taxonomies and shared helpers.

Conventions:
- Most classes use the `Singleton` trait.
- Hooks are declared in `register_actions()`/`register_filters()` methods.
- Side effects are centralized via `Admin::load_instances()`.

## Assets and Vite
Folder: `themes/travel-concierge-me-theme/assets/`
- `package.json` scripts:
  - `dev` → `vite`
  - `build` → `vite build`
- `vite.config.js` (with `@vitejs/plugin-react`):
  - Inputs:
    - `front`, `admin` JS
    - `styles/front.scss`, `styles/admin.scss`
    - Block entries: `blocks/form-input/index` (JSX) and `blocks/form-input/editor`/`style` (SCSS)
  - Output pattern:
    - Scripts → `dist/scripts/[name].js` except blocks preserved as `dist/blocks/...`
    - Styles → `dist/styles/[name].[ext]` (blocks preserved as `dist/blocks/...`)
  - `manifest: true` to integrate with theme loader/asset resolver.

Blocks structure:
- Definitions/styles: `themes/<ACTIVE_THEME>/blocks/form-input/{block.json, editor.scss, style.scss}`
- React component: `themes/<ACTIVE_THEME>/assets/scripts/blocks/form-input.jsx`
- The `BlocksManager` registers blocks and their server-side render callbacks.

## Docs Guidelines (Theme `docs/`)
- BEM naming and SCSS architecture are documented under `themes/<ACTIVE_THEME>/docs/`.
- Key docs:
  - `bem-conventions.md`, `bem-naming.md` → CSS methodology
  - `scss-architecture.md` → abstracts/base/components/layout/sections structure
  - `class-loading-architecture.md` → Composer-first bootstrap, lifecycle, and singletons
  - `html-template-guidelines.md`, `code-documentation-guidelines.md` → standards

Essentials:
- Keep `functions.php` minimal; prefer classes under `classes/`.
- Add new setup tasks in `Admin` or a dedicated class and hook via `register_actions()`.
- Follow BEM + SCSS layered imports in `assets/styles/front.scss` and related files.

## How Services Connect to WordPress & Theme
- WordPress loads the active theme from the mounted path (`/var/www/html/wp-content/themes/${ACTIVE_THEME}`).
- Composer autoload enables class loading under `classes/`.
- Vite compiles assets; the dev server is reachable at `http://localhost:${VITE_PORT}` and production assets are written to `themes/<ACTIVE_THEME>/assets/dist/`.
- Block assets are compiled under `dist/blocks/...` and referenced via `block.json` + theme helpers.

## Core Commands (Docker)
```bash
# Build and start services
docker compose up --build -d

# Install Node dependencies for theme assets and blocks
docker compose run --rm vite npm install

# Development (Vite hot reload)
docker compose up -d vite

# Production build (assets, blocks)
docker compose run --rm vite npm run build

# Composer autoload refresh (after PHP class changes)
docker compose exec wordpress bash -lc 'cd /var/www/html/wp-content/themes/$ACTIVE_THEME && composer dump-autoload -o'

# Check Vite logs
docker compose logs -f vite
```

## Notes for AI Prompts
- Refer to this file for service names, ports, mounts, and theme paths.
- Assume Composer autoload is present and classes resolve via `vendor/autoload.php` loaded by `inc/loader.php`.
- When implementing new features:
  - Place PHP logic in `classes/` with `Base` lifecycle and `Singleton` where appropriate.
  - Add assets under `assets/scripts/` or `assets/styles/` and register via `Enqueue`.
  - For Gutenberg blocks: definitions in `blocks/`, React in `assets/scripts/blocks/`, register via `BlocksManager`.
- Keep README minimal; this document is the canonical architecture context for tools/AI.