# Project Context: Docker + WordPress + Vite + Theme

> **Single source of truth** for the Travel Concierge Me platform.
> Every statement in this document is backed by actual repository files.
> Last verified: 2026-03-24. Updated: 2026-03-24 — added §19 guest-name validation layers.

---

## 1. Stack Overview

| Layer | Technology | Role |
|-------|-----------|------|
| Orchestration | Docker Compose (`docker-compose.yaml`) | 6 services: `wordpress`, `nginx`, `db`, `vite`, `blocks`, `mailer` |
| Backend | WordPress (latest) + PHP 8.x (Apache) | CMS, REST API, theme runtime |
| Database | MySQL 8.0 | Persistent storage via `db_data` volume |
| Assets (JS/SCSS) | Vite 4 + Node 18 | Dev server + production build for theme assets |
| Blocks | `@wordpress/scripts` 27 + webpack | Gutenberg blocks (separate from Vite) |
| Email (dev) | Mailpit | SMTP catch-all for local development |
| PHP deps | Composer (classmap autoload for `classes/`) | `symfony/string`, `symfony/translation-contracts`, `guzzlehttp/guzzle` |

> **Note:** The `php` (PHP-FPM) service is **commented out** in `docker-compose.yaml`. The `wordpress` service runs Apache with mod_php.

---

## 2. Docker Services

**File:** `docker-compose.yaml`

### 2.1 `wordpress`

- **Build context:** `docker/wordpress/Dockerfile` (base: `wordpress:latest`)
- **Port:** `${WP_PORT}:80`
- **Volumes:**
  - `wordpress_data:/var/www/html` (WP core)
  - `./themes/${ACTIVE_THEME}:/var/www/html/wp-content/themes/${ACTIVE_THEME}` (theme bind-mount)
- **Entrypoint:** `docker/scripts/wp-entrypoint.sh`
  - Calls `install-required-plugins.sh` (WP-CLI, reads `required-plugins.json` from theme)
  - Runs `composer install --no-dev --optimize-autoloader` in theme dir if `composer.json` exists
  - Hands off to the stock WordPress entrypoint (`docker-entrypoint.sh`)
- **Environment variables passed through:** `ACTIVE_THEME`, `WORDPRESS_DB_*`, `VITE_PORT`, `WP_ENV`, `PREFIX`, `TBOH_API_*`, `HOTELBEDS_API_*`, `TCM_ACTIVE_PROVIDERS`, `TCM_DEBUG_*`, `TCM_SIMULATE_*`, `WP_DEBUG`
- **Depends on:** `db`

### 2.2 `nginx`

- **Image:** `nginx:latest`
- **Port:** `${NGINX_PORT}:80`
- **Config:** `nginx.conf` (proxies PHP to `php:9000` — currently non-functional since the `php` service is commented out)
- **Volume:** Theme bind-mount (same as `wordpress`)
- **Depends on:** `wordpress`

### 2.3 `db`

- **Image:** `mysql:8.0` (`linux/x86_64`)
- **Port:** `${MYSQL_PORT}:3306`
- **Volume:** `db_data:/var/lib/mysql`
- **Extra flags:** `--skip-ssl --require_secure_transport=OFF`

### 2.4 `vite`

- **Image:** `node:18`
- **Working dir:** `/app`
- **User:** `1000:1000` (non-root)
- **Volume:** `./themes/${ACTIVE_THEME}/assets:/app`
- **Port:** `${VITE_PORT}:${VITE_PORT}`
- **Command:** `sh -c "chmod +x node_modules/esbuild/bin/esbuild && npm install && npm run dev"`
- **Depends on:** `wordpress`

### 2.5 `blocks`

- **Image:** `node:18`
- **Working dir:** `/app/blocks`
- **User:** `1000:1000`
- **Volume:** `./themes/${ACTIVE_THEME}/blocks:/app/blocks`
- **Command:** `sh -c "cd forms-entries && npm install && npm run dev"` (watches block source in `forms-entries/`)
- **Depends on:** `wordpress`

### 2.6 `mailer`

- **Image:** `axllent/mailpit`
- **Ports:** `8025:8025` (web UI), `1025:1025` (SMTP)
- **Volume:** `mailer_data:/data`
- **Restart:** `unless-stopped`

### Named Volumes

`wordpress_data`, `db_data`, `mailer_data`

---

## 3. Docker Build & Scripts

### 3.1 WordPress Dockerfile (`docker/wordpress/Dockerfile`)

Based on `wordpress:latest`. During build:

1. `docker/scripts/install-system-dependencies.sh` — installs `less`, `mariadb-client`, `curl`, `unzip`, `git`, `jq`, **WP-CLI**, **Composer**
2. Copies `install-theme-dependencies.sh`, `install-required-plugins.sh`, `wp-entrypoint.sh` into image
3. Copies `docker/wordpress/php.ini` and `docker/wordpress/apache-uploads.conf`
4. Sets custom entrypoint: `wp-entrypoint.sh`

### 3.2 php.ini (`docker/wordpress/php.ini`)

```ini
upload_max_filesize = 256M
post_max_size       = 256M
max_execution_time  = 9999
max_input_time      = 9999
memory_limit        = 256M
```

> ⚠️ `max_execution_time` and `max_input_time` are set to 9999s — development only.

### 3.3 apache-uploads.conf (`docker/wordpress/apache-uploads.conf`)

Overrides: `upload_max_filesize=256M`, `post_max_size=256M`, `max_execution_time=300`, `max_input_time=300`, `memory_limit=256M`, `LimitRequestBody=268435456` (256 MB).

### 3.4 Root-level Dockerfile (`Dockerfile`)

A **standalone Node 18** image for Vite, NOT used by `docker-compose.yaml`. It copies theme assets, runs `npm install`, and `composer install`. Exposes `${VITE_PORT}`.

---

## 4. Environment Variables

**Source:** `.env.template` (copy to `.env`).

### WordPress & Database

| Variable | Example / Default | Notes |
|----------|----------|-------|
| `ACTIVE_THEME` | `build-theme` (template) / `travel-concierge-me-theme` (actual) | Theme directory name |
| `WP_PORT` | (user-defined) | Host port → container :80 |
| `NGINX_PORT` | (user-defined) | Host port → nginx :80 |
| `MYSQL_PORT` | (user-defined) | Host port → MySQL :3306 |
| `WORDPRESS_DB_HOST` | `db` | Docker service name |
| `WORDPRESS_DB_NAME` | (user-defined) | |
| `WORDPRESS_DB_USER` | (user-defined) | |
| `WORDPRESS_DB_PASSWORD` | (user-defined) | |
| `MYSQL_ROOT_PASSWORD` | (user-defined) | |
| `WP_ENV` | `development` | Controls `tcm_is_dev()` |
| `WP_DEBUG` | `true` | Enables debug logs |

### Vite

| Variable | Example / Default | Notes |
|----------|----------|-------|
| `VITE_PORT` | (user-defined, e.g. `5159`) | Must match `vite.config.js` `server.port` |

### Provider Credentials

| Variable | Default in template | Notes |
|----------|----------|-------|
| `TBOH_API_URL` | `http://api.tbotechnology.in/TBOHolidays_HotelAPI` | TBO base URL |
| `TBOH_API_USERNAME` | (empty) | |
| `TBOH_API_PASSWORD` | (empty) | |
| `HOTELBEDS_API_URL` | `https://api.test.hotelbeds.com` | Hotelbeds base URL |
| `HOTELBEDS_API_KEY` | (empty) | |
| `HOTELBEDS_API_SECRET` | (empty) | |
| `TCM_ACTIVE_PROVIDERS` | `tbo,hotelbeds` | Comma-separated list |

### Debug / Simulation Flags

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `TCM_DEBUG_FORCE_PRICE_CHANGE` | `true/false` | `false` | Simulate price change between Search and PreBook |
| `TCM_DEBUG_FORCE_POLICY_CHANGE` | `true/false` | `false` | Simulate cancellation policy change |
| `TCM_DEBUG_FORCE_CANCEL_ERROR` | `false/recovered/escalation` | `false` | Simulate cancel API errors |
| `TCM_SIMULATE_PROVIDER_ERRORS` | `none/random/tbo/hotelbeds` | `none` | Force provider failures for resilience testing |
| `TCM_SIMULATE_HOTEL_DETAILS_ERROR` | `0` | `0` | Simulate hotel details endpoint errors |
### Cron / Async Execution

| Variable | Type | Default | Purpose |
|----------|------|---------|--------|
| `TCM_DISABLE_WP_CRON` | `true/false/1/yes/on` | `false` | When truthy, defines WordPress `DISABLE_WP_CRON` constant — disables pseudo-cron (page-load–triggered). Requires a real system cron to call `wp-cron.php`. See §18. |
---

## 5. Theme Architecture

### 5.1 Location & Bootstrap

- **Host path:** `themes/travel-concierge-me-theme/`
- **Container path:** `/var/www/html/wp-content/themes/travel-concierge-me-theme`

**Boot sequence** (`functions.php`):

1. Defines `TCM_API_DEBUG_MODE = true`
2. Requires `inc/env.php` — defines constants: `TCM_VERSION` (`2025.12.2`), `TEMPLATE_DIR`, `TEMPLATE_DIR_URI`, `WP_ENV`, `PREFIX` (`tcm_`), `TCM_DB_MIGRATION_VERSION`; also reads `TCM_DISABLE_WP_CRON` and conditionally defines `DISABLE_WP_CRON` for WordPress runtime cron behavior
3. Requires `inc/loader.php` — loads Composer autoloader, helper files, registers WP-CLI commands (`CliMigration`, `CliCircuitBreaker`, `CliCron`), inits `TCM_Cache`, `TCM_CacheHousekeeping`, `AsyncHeartbeat`; registers TBO post-book cron action (see §18)
4. Instantiates `Admin::getInstance()` — bootstraps the entire theme lifecycle

### 5.2 Helper Files (`inc/helpers/`)

| File | Key Functions |
|------|--------------|
| `admin-helpers.php` | `tcm_is_dev()`, `tcm_get_asset()`, `tcm_get_asset_version()`, `tcm_load_textdomain()` |
| `front-helpers.php` | `tcm_render_component()`, `tcm_render_partial()`, anti-FOUC CSS for booking pages |
| `form-builder.php` | Form building utilities |

**`tcm_get_asset(string $relative_path): array`** — Returns `['src' => url, 'ver' => version]`.
- **Dev mode:** `http://localhost:{VITE_PORT}/{relative_path}` (`ver = null`)
- **Prod mode:** Resolves from `assets/dist/manifest.json` with fallback strategies (exact key → file/src match → extension swap). Version = `filemtime()` or `TCM_VERSION`.

**`tcm_is_dev(): bool`** — Checks (in order): `getenv('WP_ENV') === 'development'`, constant `WP_ENV === 'development'`, or `.vite` file exists in theme dir.

### 5.3 Composer (`composer.json`)

```json
{
  "name": "tcm/tcm-theme",
  "type": "wordpress-theme",
  "require": {
    "symfony/string": "^6.0",
    "symfony/translation-contracts": "^3.0",
    "guzzlehttp/guzzle": "^7.0"
  },
  "autoload": {
    "classmap": ["classes/"]
  }
}
```

All classes under `classes/` are auto-discovered by Composer classmap. **No `require_once` needed** for classes in that tree.

### 5.4 Required Plugins (`required-plugins.json`)

Installed automatically by `install-required-plugins.sh` on container start:

| Plugin | Auto-activate |
|--------|:---:|
| `wp-fastest-cache` | ✅ |
| `laravel-dd` | ✅ |
| `wp-mail-smtp` | ✅ |
| `user-switching` | ✅ |
| `ultimate-addons-for-gutenberg` (Spectra) | ✅ |

### 5.5 WP-CLI Commands

Registered in `inc/loader.php` (under `WP_CLI` guard, classes in `classes/Cli/`):

| Command | Class | Purpose |
|---------|-------|--------|
| `wp my-wp-tables-migrate` | `CliMigration` | Run database migrations |
| `wp tcm-circuit` | `CliCircuitBreaker` | Inspect / reset provider circuit-breaker state |
| `wp tcm-cron status` | `CliCron` | Show cron mode, scheduled TCM hooks, and async heartbeat last-run |

### 5.6 Navigation Menus

Registered in `Admin::register_menus()`:

`primary`, `secondary`, `visitor_primary`, `visitor_secondary`

### 5.7 Theme Supports

`post-thumbnails`, `editor-styles`, `wp-block-styles`, `responsive-embeds`, `align-wide`

---

## 6. Classes Architecture

**Root:** `themes/travel-concierge-me-theme/classes/`

### 6.1 Directory Structure

```
classes/
├── Admin/
│   ├── Admin.php              # Theme lifecycle bootstrap (load_instances, menus, setup)
│   ├── CacheReportPage.php    # Admin page: cache report (submenu under TCM Settings)
│   ├── Enqueue.php            # Asset registration (dev/prod, type="module")
│   ├── FormsEntriesPage.php   # Admin page: forms entries
│   ├── PageOptions.php        # Meta boxes for page options
│   ├── Redirects.php          # Admin redirect rules
│   ├── SettingsPage.php       # TCM Settings admin page
│   └── ThemeActivator.php     # Theme activation tasks
├── Base/
│   ├── Base.php               # Lifecycle: init(), register_actions(), register_filters()
│   └── ThemeActivation.php    # Hooks for theme activation (migration triggers)
├── Blocks/
│   └── BlocksManager.php      # Auto-discovers and registers Gutenberg blocks
├── Cli/
│   ├── CliMigration.php       # WP-CLI: wp my-wp-tables-migrate
│   ├── CliCircuitBreaker.php  # WP-CLI: wp tcm-circuit
│   └── CliCron.php            # WP-CLI: wp tcm-cron (cron mode, events, heartbeat)
├── Database/
│   ├── BaseMigration.php      # Abstract migration base
│   ├── BaseTable.php          # Abstract table base
│   ├── DatabaseManager.php    # Migration orchestrator (runs on init + theme switch)
│   ├── DatabaseRunner.php     # SQL migration runner
│   ├── BookingGuests/         # Migration: booking_guests table
│   ├── BookingItems/          # Migration: booking_items table
│   ├── BookingPassengers/     # Migration: booking_passengers table
│   ├── BookingRefs/           # Migration: booking_refs table
│   ├── BookingStatusEvents/   # Migration: booking_status_events table
│   ├── Bookings/              # Migration: bookings table
│   ├── Customers/             # Migration: customers table
│   ├── FormsEntries/          # Migration: forms_entries table
│   ├── Guests/                # Migration: guests table
│   ├── Nationalities/         # Migration: nationalities table
│   └── WorldCities/           # Migration: world_cities table
├── Diagnostics/
│   └── AsyncHeartbeat.php     # Recurring cron heartbeat — diagnostic only (see §18)
├── Endpoints/
│   ├── BaseEndpoint.php       # Abstract base (hooks register_routes into rest_api_init)
│   ├── UnifiedHotelEndpoint.php  # Multi-provider hotel search
│   ├── BookingSession/        # Booking session CRUD
│   ├── Destinations/          # City/destination search
│   ├── FormsEntries/          # Form entries CRUD
│   ├── Hotelbeds/             # Hotelbeds-specific booking operations
│   ├── Nationalities/         # Nationality options
│   ├── TBO/                   # TBO-specific booking operations
│   ├── UserBooking/           # User booking queries
│   ├── Debug/                 # (empty)
│   └── UnifiedBooking/        # (empty)
├── PostTypes/
│   └── Inmueble.php           # Custom post type
├── Providers/                 # Hotel provider implementations (see §8)
├── Taxonomies/
│   └── Caracteristicas.php    # Custom taxonomy
├── Traits/
│   ├── CacheTtl.php           # Centralized TTL definitions
│   ├── EndpointLogger.php     # Auto-logging for endpoints
│   ├── Entity.php             # Entity trait
│   ├── Fields.php             # Field definitions
│   ├── Singleton.php          # Singleton pattern
│   ├── TCM_Cache.php          # Cache API with SWR support
│   ├── TCM_CacheHousekeeping.php  # Cron-based cache purge
│   ├── TCM_CacheReport.php    # Cache statistics
│   ├── TCM_CircuitBreaker.php # Provider circuit breaker
│   └── TransientKeys.php      # Centralized cache key patterns
└── Users/
    └── UsersManager.php        # User roles/capabilities
```

### 6.2 Conventions

- Most classes extend `Base` and use the `Singleton` trait
- Hooks are registered in `register_actions()` / `register_filters()` methods
- All side effects are centralized via `Admin::load_instances()`
- `Base.php` provides `add_action()` / `add_filter()` helper wrappers

### 6.3 Instances Loaded by Admin

The following singletons are initialized in `Admin::load_instances()` (in order):

`Enqueue`, `BlocksManager`, `UsersManager`, `Redirects`, `ThemeActivator`, `DatabaseManager`, `FormsEntriesEndpoint`, `DestinationsEndpoint`, `TBOEndpoint`, `HotelbedsEndpoint`, `UnifiedHotelEndpoint`, `UserBookingEndpoint`, `NationalitiesEndpoint`, `BookingSessionEndpoint`, `FormsEntriesPage`, `SettingsPage`, `CacheReportPage`, `PageOptions`

---

## 7. REST API Endpoints

**Base route:** `/wp-json/tcm/v1/`

### 7.1 Unified Hotel Search

| Method | Route | Class | Auth | Notes |
|--------|-------|-------|------|-------|
| POST | `/hotels-search` | `UnifiedHotelEndpoint` | Public | Multi-provider search with pagination |

**Request body:**
```json
{
  "geonameId": 3531673,
  "checkIn": "2026-03-20",
  "checkOut": "2026-03-22",
  "nationality": "MX",
  "paxRooms": [{"adults": 2, "children": 0}],
  "page": 1,
  "perPage": 10
}
```

### 7.2 Provider-Specific Booking (TBO)

| Method | Route | Class | Auth |
|--------|-------|-------|------|
| GET | `/hotel-list` | `TBOEndpoint` | Nonce |
| POST | `/booking/prebook` | `TBOEndpoint` | Nonce |
| POST | `/booking/book` | `TBOEndpoint` | Nonce |
| POST | `/booking/detail` | `TBOEndpoint` | Public (with confirmation #) |
| POST | `/booking/cancel` | `TBOEndpoint` | Nonce |
| POST | `/booking/cancel/{id}` | `TBOEndpoint` | Nonce (legacy) |
| POST | `/booking/details-by-date` | `TBOEndpoint` | Public (with confirmation #) |

### 7.3 Provider-Specific Booking (Hotelbeds)

| Method | Route | Class | Auth |
|--------|-------|-------|------|
| POST | `/hotelbeds/checkrates` | `HotelbedsEndpoint` | Nonce |
| POST | `/hotelbeds/bookings` | `HotelbedsEndpoint` | Nonce |
| GET | `/hotelbeds/bookings` | `HotelbedsEndpoint` | Nonce |
| GET | `/hotelbeds/bookings/{id}` | `HotelbedsEndpoint` | Nonce |
| DELETE | `/hotelbeds/bookings/{id}` | `HotelbedsEndpoint` | Nonce |

### 7.4 Booking Session

| Method | Route | Class | Auth |
|--------|-------|-------|------|
| POST | `/booking-session` | `BookingSessionEndpoint` | Nonce (allows guests) |
| GET | `/booking-session/{uuid}` | `BookingSessionEndpoint` | Nonce |
| POST | `/booking-session/{uuid}/renew` | `BookingSessionEndpoint` | Nonce |
| POST | `/booking-session/{uuid}/validate` | `BookingSessionEndpoint` | Nonce |
| PUT | `/booking-session/{uuid}` | `BookingSessionEndpoint` | Nonce |

### 7.5 Other Endpoints

| Method | Route | Class | Auth |
|--------|-------|-------|------|
| GET | `/destinations` | `DestinationsEndpoint` | Public |
| POST | `/forms-entries` | `FormsEntriesEndpoint` | Nonce + logged in |
| GET | `/forms-entries` | `FormsEntriesEndpoint` | Nonce + logged in |
| GET | `/forms-entries/{id}` | `FormsEntriesEndpoint` | Nonce + logged in |
| GET | `/nationalities-options` | `NationalitiesEndpoint` | Nonce + logged in |
| GET | `/user/bookings` | `UserBookingEndpoint` | Logged in |
| GET | `/user/bookings/{booking_id}` | `UserBookingEndpoint` | Logged in |
| GET | `/user/bookings/search` | `UserBookingEndpoint` | Logged in |

### 7.6 Security

- `X-WP-Nonce` header with `wp_rest` nonce required for authenticated endpoints
- Nonce + endpoint map localized to frontend via `TCM` global in `Enqueue.php`
- Credentials loaded from environment variables (see §4)

---

## 8. Multi-Provider Hotel Search Architecture

### 8.1 Core Principles

1. **Canonical Format** — All provider data transforms to/from a standard format at the provider boundary
2. **Provider Isolation** — Database tables remain vendor-agnostic; provider-specific logic in `classes/Providers/{ProviderName}/`
3. **Two-Tier Cache** — L1 (raw provider data) + L2 (canonical format)
4. **Parallel Execution** — Multiple providers execute simultaneously via Guzzle async HTTP loopback

### 8.2 Provider Directory Structure

```
classes/Providers/
├── Interfaces/
│   └── HotelProviderInterface.php     # Contract for all providers
├── Schemas/
│   ├── CanonicalSchema.php            # Schema v1 field definitions
│   ├── CanonicalValidator.php         # Validates canonical data
│   └── CardSafeSchema.php            # Card-safe field subset
├── Traits/
│   ├── CanonicalCache.php             # L2 canonical cache (7d TTL)
│   ├── CanonicalHelpers.php           # Shared builders (money, room, guest)
│   └── HotelContentSwr.php           # SWR + circuit breaker for hotel content
├── ProviderFactory.php                # Factory: make('tbo'|'hotelbeds')
├── Hotelbeds/
│   ├── HotelbedsHotelProvider.php     # implements HotelProviderInterface
│   ├── README.md
│   └── Traits/
│       └── HotelbedsApiClient.php     # API communication + L1 cache
└── Tbo/
    ├── TboHotelProvider.php           # implements HotelProviderInterface
    └── Traits/
        └── TboApiClient.php           # API communication + L1 cache
```

### 8.3 HotelProviderInterface

**File:** `classes/Providers/Interfaces/HotelProviderInterface.php`

| Method | Returns | Purpose |
|--------|---------|---------|
| `search(array $search_request)` | `array` | Canonical search |
| `prebook(array $session)` | `array` | Hold reservation |
| `book(array $session)` | `array` | Confirm reservation |
| `cancel(array $booking_data)` | `array` | Cancel booking |
| `get_booking_detail(array $booking_ref)` | `array` | Retrieve booking status |
| `get_capabilities()` | `array` | Feature flags |
| `get_provider_name()` | `string` | `'tbo'` or `'hotelbeds'` |
| `get_api_version()` | `string` | API version string |

### 8.4 Provider Implementations

**HotelbedsHotelProvider:**
- Uses traits: `HotelbedsApiClient`, `CanonicalCache`, `CanonicalHelpers`, `HotelContentSwr`
- Constructor: `__construct($api_url, $api_key, $api_secret)`
- Const: `IMAGE_BASE_URL = 'http://photos.hotelbeds.com/giata/'`

**TboHotelProvider:**
- Uses traits: `TboApiClient`, `CanonicalCache`, `CanonicalHelpers`, `HotelContentSwr`
- Constructor: `__construct($api_url, $username, $password)`
- Protected constants (TBO certification — **do not modify**):
  - `MAX_HOTEL_CODES_PER_REQUEST = 100`, `BOOK_TIMEOUT_SECONDS = 120`
  - `NAME_MIN_LENGTH = 3`, `NAME_MAX_LENGTH = 25`
  - `RESPONSE_TIME_FAST = 10`, `RESPONSE_TIME_NORMAL = 15`, `RESPONSE_TIME_EXHAUSTIVE = 23`
  - `MAX_ROOMS = 6`, `MAX_ADULTS_PER_ROOM = 6`, `MAX_CHILDREN_PER_ROOM = 4`
- Key certification methods (TBO feedback #13 — **do not weaken**):
  - `normalize_name(string $name)` — AsciiSlugger transliteration, digit stripping, length clamped to 3–25 chars; runs for every guest name before the TBO `/Book` request
  - `validate_book_session(array $session)` — last-resort guard; checks min-length, digit presence, and email for all guests before any TBO API call
- Guest-name validation is multi-layer (see §19).

**ProviderFactory:**
- `ProviderFactory::make('tbo')` → reads `TBOH_API_URL`, `TBOH_API_USERNAME`, `TBOH_API_PASSWORD`
- `ProviderFactory::make('hotelbeds')` → reads `HOTELBEDS_API_URL`, `HOTELBEDS_API_KEY`, `HOTELBEDS_API_SECRET`
- Returns `WP_Error` if credentials missing

### 8.5 Parallel Execution (UnifiedHotelEndpoint)

**File:** `classes/Endpoints/UnifiedHotelEndpoint.php`

- **Single provider:** calls `execute_providers_sequential()` → direct `$provider->search()`
- **Multiple providers:** calls `execute_providers_parallel()`:
  1. Creates Guzzle client (60s timeout, SSL verify disabled)
  2. For each provider: dispatches `postAsync()` to the **same** `/tcm/v1/hotels-search` with `force_provider` param (25s individual timeout)
  3. Uses `GuzzleHttp\Promise\Utils::settle()` for concurrent resolution
  4. `merge_provider_results()` combines results with pagination via `array_slice()`

### 8.6 Canonical Schema (v1)

**File:** `classes/Providers/Schemas/CanonicalSchema.php`

**Booking Detail (top-level):** `bookingId`, `confirmationNumber`, `invoiceNumber`, `bookingStatus`, `bookingDate`, `checkIn`, `checkOut`, `hotelName`, `hotelRating`, `hotelCity`, `totalFare` (money), `totalTax` (money), `totalAmount` (money), `currency`, `noOfRooms`, `rooms[]`, `guestDetails[]`, `cancellationPolicy[]`, `hotelNorms[]`, `hotelData`

**Money object:** `{amount: float, currency: string}`

**Room:** `name`, `inclusion`, `mealType`, `isRefundable`, `roomPromotion`, `totalFare`, `totalTax`, `currency`, `status`, `cancelPolicies[]`

**Guest:** `room`, `guestNumber`, `title`, `firstName`, `lastName`, `type`, `age`, `email`, `phone`

**Cancel Policy:** `fromDate`, `chargeType` (`'Fixed'`|`'Percentage'`), `chargeAmount`

**Hotel Data:** `hotelCode`, `hotelName`, `rating`, `address`, `city`, `coordinates`

---

## 9. Caching Architecture

### 9.1 TCM_Cache (`classes/Traits/TCM_Cache.php`)

Central cache API wrapping WordPress transients with SWR (Stale-While-Revalidate) support.

**Core methods:**

| Method | Purpose |
|--------|---------|
| `TCM_Cache::get($group, $parts)` | Read transient (returns `null` on miss, not `false`) |
| `TCM_Cache::set($group, $parts, $value, $ttl?)` | Write transient (TTL from `CacheTtl` if null) |
| `TCM_Cache::delete($group, $parts)` | Delete transient |
| `TCM_Cache::build_key($group, $parts)` | Build key via `TransientKeys::build()` |
| `TCM_Cache::set_with_stale($group, $parts, $value, $fresh_ttl?, $stale_ttl?)` | Write fresh + stale keys |
| `TCM_Cache::get_swr($group, $parts, $fetch_cb, $opts)` | SWR: fresh hit → return; stale hit → return + schedule cron refresh; miss → sync fetch |

**SWR constants:** `SWR_CRON_HOOK = 'tcm_swr_refresh'`, stale TTL default: 90 days, lock TTL: 300s.

**Metrics:** Tracks `hits`, `misses`, `sets`, `deletes`, `swr_stale` per-request. Logged on shutdown when `WP_DEBUG` is true.

### 9.2 Cache TTLs (`classes/Traits/CacheTtl.php`)

| Group | TTL | Notes |
|-------|-----|-------|
| `hotel_content_hotelbeds` | 30 days | L1: raw Hotelbeds content |
| `hotel_content_tbo` | 24 hours | L1: raw TBO content |
| `hotel_content_miss` | 1 hour | Cache "not found" hotel |
| `canonical` | 7 days | L2: canonical format |
| `rate_conditions` | 7 days | Rate conditions |
| `country_map` | 24 hours | Provider country mappings |
| `country_list` | 24 hours | Country lists |
| `nationalities` | 24 hours | Nationality options |
| `hotel_code_list` | 30 minutes | Hotel code lists |
| `session_initial` | 10 minutes | Booking session |
| `session_max` | 30 minutes | Max session lifetime |
| `session_extend` | 10 minutes | Session extension |
| `session_fallback` | 15 minutes | Session fallback |
| `swr_stale` | 90 days | SWR stale data |
| `swr_lock` | 5 minutes | SWR refresh lock |
| `circuit_window` | 5 minutes | Circuit breaker window |
| `circuit_open` | 5 minutes | Circuit open duration |
| `circuit_last_opened` | 24 hours | Last trip timestamp |
| `housekeeping_lock` | 5 minutes | Housekeeping lock |

### 9.3 Transient Key Patterns (`classes/Traits/TransientKeys.php`)

**Prefix:** `tcm`, **Separator:** `:`, **Max length:** 172 chars

| Method | Pattern |
|--------|---------|
| `TransientKeys::bookingSession($uuid)` | `tcm:session:booking:{uuid}` |
| `TransientKeys::hotelContent($provider, $code)` | `tcm:hotel_content:{provider}:{code}` |
| `TransientKeys::canonical($version, $provider, $code)` | `tcm:canonical:v{version}:{provider}:{code}` |
| `TransientKeys::rateConditions($provider, $hotel, $rate)` | `tcm:rate_conditions:{provider}:{hotel}:{rate}` |
| `TransientKeys::countryMap($provider)` | `tcm:ref:{provider}:countries` |
| `TransientKeys::nationalities()` | `tcm:ref:nationalities` |
| `TransientKeys::apiCache($provider, $hash)` | `tcm:api_cache:{provider}:{hash}` |
| `TransientKeys::rateLimit($action, $session)` | `tcm:rate_limit:{action}:{session}` |
| `TransientKeys::housekeepingLock()` | `tcm:housekeeping:lock` |

### 9.4 Two-Tier Cache Strategy

**L1 Cache (Raw Provider Data):**
- Purpose: Cache raw API responses before transformation
- Keys: `tcm:hotel_content:{provider}:{code}`
- TTL: 30 days (Hotelbeds), 24 hours (TBO)
- Pattern: SmartCache — check individual → batch fetch missing → store individual

**L2 Cache (Canonical Format):**
- Purpose: Skip expensive transformation on cache hit
- Keys: `tcm:canonical:v1:{provider}:{code}` (versioned, `CANONICAL_CACHE_VERSION = 1`)
- TTL: 7 days
- Pattern: Check L2 → transform if miss → validate → store
- Validation: requires non-empty `hotelCode` and `hotelName` before caching
- Bulk DELETE uses `LIMIT 10000` to prevent timeouts

### 9.5 SWR + Circuit Breaker for Hotel Content

**Trait:** `HotelContentSwr` (`classes/Providers/Traits/HotelContentSwr.php`)

3-phase flow for fetching hotel content:
1. **Pre-scan:** Check fresh transient cache per hotel
2. **Batch pre-warm:** If circuit CLOSED, call batch API for non-fresh hotels; store via `TCM_Cache::set_with_stale()`
3. **Per-hotel SWR:** `TCM_Cache::get_swr()` resolves fresh → stale → miss

When circuit is **OPEN** (provider failing), Phase 2 is skipped — stale data is returned when available.

### 9.6 Cache Housekeeping (`classes/Traits/TCM_CacheHousekeeping.php`)

- **Cron schedule:** `tcm_six_hours` (every 6 hours)
- **Cron hook:** `tcm_cache_housekeeping`
- **Batch size:** 500 rows per iteration, max 10 iterations (5,000 rows/run)
- **Lock TTL:** 300s (prevents concurrent runs)
- **Behavior:** Finds expired `_transient_timeout_*` rows, deletes corresponding value rows in batch
- **Reporting:** Calls `TCM_CacheReport::store()` after cleanup

### 9.7 Circuit Breaker (`classes/Traits/TCM_CircuitBreaker.php`)

Provider-level circuit breaker using transients.

| Constant | Value |
|----------|-------|
| `FAILURE_THRESHOLD` | 10 failures |
| `FAILURE_RATE_THRESHOLD` | 50% |
| `WINDOW_TTL` | 5 minutes |
| `OPEN_TTL` | 5 minutes |
| `MAX_REASONS` | 20 stored |
| `LAST_OPENED_TTL` | 24 hours |

**Lifecycle:** `CLOSED` → (≥ 10 failures AND ≥ 50% rate) → `OPEN` → (5 min expiry) → `HALF-OPEN` → probe succeeds → `CLOSED`

**Methods:** `record_success()`, `record_failure()`, `should_short_circuit()`, `get_status()`, `get_all_statuses()`, `reset()`

---

## 10. Database Migrations

**Manager:** `DatabaseManager` (runs on `init` priority 1 and `after_switch_theme`).

### Always-run migrations

| Class | Table (prefixed `wp_tcm_`) |
|-------|---------------------------|
| `FormsEntriesMigration` | `forms_entries` |
| `WorldCitiesMigration` | `world_cities` |
| `NationalitiesMigration` | `nationalities` |

### Conditional migrations (require `USE_DATABASE === true` in `wp-config.php`)

| Class | Table | FK |
|-------|-------|-----|
| `BookingsMigration` | `bookings` | — |
| `BookingGuestsMigration` | `booking_guests` | → bookings |
| `BookingItemsMigration` | `booking_items` | → bookings |
| `BookingStatusEventsMigration` | `booking_status_events` | → bookings |
| `BookingRefsMigration` | `booking_refs` | → bookings |

> Without `USE_DATABASE === true`, booking tables are **not created** and a warning is logged.

---

## 11. Assets & Vite

### 11.1 Vite Configuration (`assets/vite.config.js`)

**Inputs:**

| Entry | File |
|-------|------|
| `front` | `scripts/front.js` |
| `admin` | `scripts/admin.js` |
| `react-app` | `scripts/react-app.jsx` |
| `styles/admin` | `styles/admin.scss` |
| `styles/editor` | `styles/editor.scss` |
| `styles/criticals` | `styles/criticals.scss` |

> `styles/front.scss` is imported **inside** `scripts/front.js` (not a separate entry point).

**Output:** `scripts/[name].js`, `styles/[name].[ext]`, chunks in `scripts/chunks/[name]-[hash].js`

**Features:** `manifest: true`, `modulePreload: false`, React plugin with React Compiler (target 18), SCSS `additionalData` prepends `styles/abstracts/variables.scss`.

**Dev server:** `host: true`, port `5159`, `strictPort: true`, polling (100ms) for Docker FS.

### 11.2 NPM Scripts (`assets/package.json`)

| Script | Command |
|--------|---------|
| `dev` | `vite` |
| `build` | `vite build` |
| `preview` | `vite preview` |

**Key dependencies:** React 18, Redux + redux-thunk, Splide.js, flatpickr, dayjs, normalize.css, babel-plugin-react-compiler.

### 11.3 Frontend JS Architecture (`assets/scripts/`)

```
scripts/
├── front.js                  # Main frontend entry
├── admin.js                  # Admin entry
├── react-app.jsx             # React playground (page-playground.php only)
├── classes/                  # Manager classes (BookingSessionManager, HotelFiltersManager, etc.)
├── modules/                  # Init modules (initHotelResults, initBookingSession, etc.)
├── renderers/                # Block renderers
├── store/                    # Redux store (slices, selectors, middleware, api/)
└── utils/                    # TextNormalizer, logger, apiPerformanceMonitor, etc.
```

### 11.4 Enqueue (PHP side — `classes/Admin/Enqueue.php`)

**Front scripts:** `front-script-js` → `tcm_get_asset('scripts/front.js')` with `type="module"`. Localizes `TCM` global:
- `TCM.api.baseUrl` — wp-json base URL
- `TCM.api.nonce` — `wp_create_nonce('wp_rest')`
- `TCM.api.endpoints` — map of endpoint names with `path`, `url`, `status`, `methods`

**Admin scripts:** `admin-script-js` → `tcm_get_asset('scripts/admin.js')` with `type="module"`. Localizes `TCM.nationalities`.

**React app:** Enqueued only on `page-playground.php` → `react-app-js` with `type="module"`.

**Styles:**
| Handle | Asset | Priority | Notes |
|--------|-------|----------|-------|
| `front-critical-css` | `styles/criticals.scss` | 0 | Critical above-the-fold CSS |
| `front-style-css` | `scripts/front.css` | 1 | Skipped in dev mode (Vite handles it) |
| `admin-style-css` | `styles/admin.scss` | 1 | Skipped in dev mode |
| `normalize-css` | `assets/public/vendor/normalize.css` | — | Normalize v8.0.1 |

**Dev mode preamble:** Injects Vite React refresh + `@vite/client` scripts in `wp_footer`.

**Google Fonts:** Nunito (200–900) + Roboto (100–900) with `display=swap` and preconnect hints.

### 11.5 SCSS Architecture (`assets/styles/`)

```
styles/
├── abstracts/    # Variables, functions, mixins (auto-prepended by Vite)
├── mixins/       # Shared mixins
├── components/   # Component styles (forms, cards, etc.)
├── layout/       # Layout structures
├── sections/     # Page sections
├── pages/        # Page-specific styles
├── utilities/    # Utility classes
├── front.scss    # Frontend bundle entry
├── admin.scss    # Admin bundle entry
├── editor.scss   # Block editor styles
└── criticals.scss # Critical CSS entry
```

---

## 12. Gutenberg Blocks

### 12.1 Build System

**Directory:** `themes/travel-concierge-me-theme/blocks/`

- Built with `@wordpress/scripts` 27 (webpack), **not** Vite
- Source: `blocks/src/blocks/`
- Output: `blocks/build/blocks/`
- Scripts: `npm run build` (production), `npm run start` (watch)
- Dependency: `flatpickr ^4.6.13`

### 12.2 Available Blocks (source)

| Block | Directory |
|-------|-----------|
| `basic-block` | `src/blocks/basic-block/` |
| `tcm-booking-list` | `src/blocks/tcm-booking-list/` |
| `tcm-cancellation-policy` | `src/blocks/tcm-cancellation-policy/` |
| `tcm-form-container` | `src/blocks/tcm-form-container/` |
| `tcm-form-input` | `src/blocks/tcm-form-input/` |
| `tcm-guest-form` | `src/blocks/tcm-guest-form/` |
| `tcm-guest-form-item` | `src/blocks/tcm-guest-form-item/` |
| `tcm-guest-form-room` | `src/blocks/tcm-guest-form-room/` |
| `tcm-guest-info` | `src/blocks/tcm-guest-info/` |
| `tcm-guest-info-item` | `src/blocks/tcm-guest-info-item/` |
| `tcm-hotel-norms` | `src/blocks/tcm-hotel-norms/` |
| `tcm-hotels-results` | `src/blocks/tcm-hotels-results/` |
| `tcm-last-searches` | `src/blocks/tcm-last-searches/` |
| `tcm-loader` | `src/blocks/tcm-loader/` |
| `tcm-modal-content` | `src/blocks/tcm-modal-content/` |
| `tcm-pagination` | `src/blocks/tcm-pagination/` |
| `tcm-provider-selector` | `src/blocks/tcm-provider-selector/` |
| `tcm-session-hotel-info` | `src/blocks/tcm-session-hotel-info/` |
| `tcm-session-room-details` | `src/blocks/tcm-session-room-details/` |
| `tcm-session-sales-summary` | `src/blocks/tcm-session-sales-summary/` |
| `tcm-special-request` | `src/blocks/tcm-special-request/` |

Shared styles: `src/blocks/_shared-styles.scss`, shared utilities: `src/utils/`.

### 12.3 Block Registration (PHP)

**`BlocksManager`** (`classes/Blocks/BlocksManager.php`):

- Hooks into `init` → scans `blocks/build/blocks/` for subdirectories containing `block.json`
- Calls `register_block_type($folder)` for each discovered block
- Registers block category `tcm-blocks` ("Travel Concierge Me Blocks") at the top of the inserter

---

## 13. Testing

### 13.1 Test Files

**Directory:** `themes/travel-concierge-me-theme/tests/`

```
tests/
├── unit/
│   ├── js/                        # JavaScript tests
│   ├── test-booking-adapter.php   # PHP unit test
│   └── test-booking-repository.php
├── integration/
│   ├── tbo-booking-flow-test.php
│   ├── tbo-booking-with-cancel-test.php
│   ├── test-booking-integration.php
│   ├── test-destinations-endpoint.php
│   ├── test-geoname-resolution.php
│   ├── test-provider-search-comparison.js
│   ├── test-provider-search.php
│   ├── test-resolution-only.php
│   ├── test-rest-endpoints.php
│   └── test-user-booking-queries.php
├── audits/
├── helpers/
├── legacy/
└── tbo-timeout-recovery-demo.php
```

### 13.2 Root-Level Scripts

| Script | Purpose |
|--------|---------|
| `run-all-tests.sh` | Run all unit + integration tests |
| `test-provider-switch.sh` | Test TBO/Hotelbeds switching via `/tcm/v1/hotels-search` |
| `debug-booking-flow.sh` | Capture full booking flow logs |
| `clear-all-caches.sh` | Flush WP object cache, all transients, L2 canonical cache, provider-specific transients |
| `clear-transients.sh` | Clear WordPress transients only |
| `run-autoload.sh` | `composer dump-autoload -o` inside WordPress container |
| `run-build.sh` | Build blocks + Vite assets |
| `run-migrations.sh` | `wp my-wp-tables-migrate --force=true` |
| `run-plugins-install.sh` | Manually trigger plugin installation |

### 13.3 Provider Error Simulation

Set `TCM_SIMULATE_PROVIDER_ERRORS` in .env or at docker compose up:

| Value | Behavior |
|-------|----------|
| `none` | Normal operation (default) |
| `random` | 50% chance each provider fails |
| `tbo` | TBO always fails |
| `hotelbeds` | Hotelbeds always fails |

```bash
TCM_SIMULATE_PROVIDER_ERRORS=tbo docker compose up -d
docker logs travel-concierge-me-builder-wordpress-1 --tail 50 | grep "🎭 Simulating"
```

### 13.4 Playground

`page-playground.php` — React playground template. Enqueues `react-app.jsx` for interactive endpoint testing.

---

## 14. Documentation Index

### 14.1 Root

| File | Purpose |
|------|---------|
| `PROJECT-CONTEXT.md` | This file — authoritative architecture reference |
| `README.md` | Setup instructions, commands, troubleshooting |
| `TODO.md` | Current sprint tasks and priorities |
| `TODO-DONE.md` | Completed tasks archive |
| `NEW-PROVIDER-CHECKLIST.md` | Steps for adding a new provider |
| `NEW-PROVIDER-TECHNICAL-DEBTS.md` | Known technical debts for provider system |

### 14.2 Theme Documentation (`themes/travel-concierge-me-theme/docs/`)

**Cache & Infrastructure:**
- `2026-03-01-tcm-cache.md`, `2026-03-01-tcm-cache-housekeeping.md`, `2026-03-01-tcm-cache-report.md`
- `2026-03-01-tcm-cache-ttl.md`, `2026-03-01-tcm-transient-keys.md`, `2026-03-01-transients-audit.md`
- `2026-03-05-tcm-provider-health.md`
- `TCM_CARD_SCHEMA.md`

**Dev Docs** (`docs/dev-docs/`):
- Architecture: `2026-02-05-multi-provider-architecture.md`, `2025-12-01-endpoints-architecture.md`, `2025-12-01-database-architecture.md`
- Conventions: `2025-12-01-bem-conventions.md`, `2025-12-01-code-documentation-guidelines.md`, `2025-11-30-html-template-guidelines.md`, `2025-12-15-scss-architecture.md`
- Booking: `2025-12-24-booking-session-implementation.md`, `2025-12-27-booking-session-architecture.md`, `2025-12-28-redux-store-architecture.md`
- Provider: `2026-01-02-provider-adapter-pattern.md`, `2026-02-09-hotel-cards-canonical-mapping.md`

**Provider API specs:**
- Hotelbeds: `docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml`, `OpenAPI-Hotel-ContentAPI-3.0.yaml`, `README.md`
- TBO: `docs/tbo-api/tbo-search-api.md`, `tbo-prebook-api.md`, `tbo-book-api.md`, `tbo-cancel-api.md`, `tbo-bookingdetail-api.md`, `tbo-hote-booking-detail-based-on-date.md`

**Edge cases:** `docs/edge-cases/2026-02-21-sanitize-text-field-corrupts-provider-ratekey.md`

**TODOs:** `docs/todos/tbo-todo.md` (TBO certification feedbacks — protected code), `docs/todos/TODO-editorconfig-line-endings.md`

**QA docs:** `docs/qa-docs/` — testing guides, e2e flows, QA reports

---

## 15. Core Commands Reference

```bash
# --- Service Management ---
docker compose up --build -d                    # Build and start all services
docker compose up -d                            # Start services
docker compose down                             # Stop services

# --- Development ---
docker compose up -d vite                       # Start Vite dev server
docker compose up -d blocks                     # Start blocks watcher
docker compose logs -f vite                     # Watch Vite logs
docker compose logs -f wordpress                # Watch WordPress logs

# --- Builds ---
./run-build.sh                                  # Build blocks + Vite assets
docker compose run --rm vite npm run build      # Vite production build only
docker compose run --rm blocks npm run build    # Blocks production build only

# --- PHP / Composer ---
./run-autoload.sh                               # Rebuild Composer autoload
docker compose exec wordpress bash              # Shell into WP container
docker compose exec wordpress wp {command}      # Run WP-CLI command

# --- Database ---
./run-migrations.sh                             # Run all DB migrations (--force=true)
docker compose exec wordpress wp my-wp-tables-migrate --force=true

# --- Cron ---
docker compose exec wordpress wp tcm-cron status                          # Show cron mode + TCM events + heartbeat
docker compose exec wordpress wp tcm-cron status --hook=tcm_tbo_post_book_detail_followup  # Filter to TBO follow-up
docker compose exec wordpress wp cron event run --due-now                 # Manually fire overdue events
docker compose exec wordpress wp option get tcm_async_test_last_run --format=json  # Raw heartbeat data

# --- Cache ---
./clear-all-caches.sh                           # Full cache clear (object cache + transients + L2 + provider)
./clear-transients.sh                           # Clear transients only
docker compose exec wordpress wp cache flush    # WP object cache flush
docker compose exec wordpress wp transient delete --all

# --- Plugins ---
./run-plugins-install.sh                        # Install required plugins

# --- Testing ---
./run-all-tests.sh                              # Run full test suite
./test-provider-switch.sh                       # Test provider switching
./debug-booking-flow.sh                         # Capture booking flow logs

# --- Logs ---
docker logs travel-concierge-me-builder-wordpress-1 --tail 100 -f
docker logs travel-concierge-me-builder-wordpress-1 --tail 50 | grep "\[TCM"
docker logs travel-concierge-me-builder-wordpress-1 --tail 50 | grep "L2-Cache"
```

---

## 16. Frontend Utilities

### 16.1 TextNormalizer (`assets/scripts/utils/TextNormalizer.js`)

Cleans up concatenated/raw text from provider APIs:
- Inserts spaces in CamelCase ("FreeParking" → "Free Parking")
- Splits letters/numbers ("24hourreception" → "24 Hour Reception")
- Handles comma/semicolon/pipe-separated lists
- Intelligent title case (preserves "WiFi", "COVID-19")
- Deduplication and punctuation cleanup

**Usage:** `TextNormalizer.normalize(rawText, {asList, joiner, dedupe, sort})`

### 16.2 HotelFiltersManager (`assets/scripts/classes/HotelFiltersManager.js`)

- Canonical mappings for cross-provider filter equivalence (meal types, amenities)
- Uses TextNormalizer before applying canonical mappings
- Works across TBO (`facilities`) and Hotelbeds (`amenities`)

### 16.3 Redux Store (`assets/scripts/store/`)

State management for booking flow: `slices/`, `selectors/`, `middleware/`, `api/`

---

## 17. Notes for AI Prompts

- Use this file as the canonical architecture context
- Composer classmap autoloads everything under `classes/` — no `require_once` needed for classes there
- New PHP features: extend `Base`, use `Singleton`, register in `Admin::load_instances()`
- New assets: add under `assets/scripts/` or `assets/styles/`, register via `Enqueue`
- New blocks: create in `blocks/src/blocks/`, build with `npm run build`, auto-discovered by `BlocksManager`
- New endpoints: extend `BaseEndpoint`, implement `register_routes()`, instantiate in `Admin::load_instances()`
- New DB tables: create Migration class in `Database/`, register in `DatabaseManager`
- Database tables MUST remain vendor-agnostic (no provider-specific columns)
- All providers implement `HotelProviderInterface` and transform to canonical format
- Never modify TBO certification constants/methods (see `docs/todos/tbo-todo.md`)
- Guest-name validation is multi-layer — see §19 before modifying any name-handling code
- After creating/moving PHP classes: run `./run-autoload.sh`
- See `TODO.md` for current sprint tasks, `TODO-DONE.md` for completed work
- Async/cron reliability is environment-dependent; see §18 before assuming scheduled events fire on time

---

## 18. Scheduled Async Flows & Cron Configuration

### 18.1 TBO Post-Book BookingDetail Follow-Up

TBO certification requires an automatic call to `/BookingDetail` after every successful `/Book` response. The system implements this as a scheduled WP-Cron single event.

| Property | Value |
|----------|-------|
| **Trigger** | `TBOEndpoint::handle_book()` — on successful TBO Book response |
| **Scheduler** | `TBOEndpoint::schedule_post_book_detail_followup()` |
| **Cron hook** | `TBOEndpoint::CRON_HOOK_POST_BOOK_DETAIL` = `tcm_tbo_post_book_detail_followup` |
| **Delay** | `TBOEndpoint::POST_BOOK_DETAIL_DELAY_SECONDS` = `120` seconds |
| **Callback** | `TBOEndpoint::handle_post_book_detail_followup()` (public static, 4 args) |
| **Registered** | `add_action(CRON_HOOK_POST_BOOK_DETAIL, ..., 10, 4)` in `inc/loader.php` |
| **Identifier** | `BookingReferenceId` (`TCM-{session_prefix}-{unix_ts}`) embedded in cron args at book time |
| **API called** | `TboHotelProvider::get_booking_detail(['bookingReferenceId' => ...])` → TBO `/BookingDetail` |

The scheduler uses `wp_next_scheduled()` to prevent duplicate scheduling for the same booking.

**Operational note:** This event is scheduled reliably, but execution within the 120-second window requires either browser traffic (pseudo-cron) or a real system cron. See §18.3.

### 18.2 Async Heartbeat (Diagnostic)

**Class:** `classes/Diagnostics/AsyncHeartbeat.php`
**Purpose:** Diagnostic only — not part of booking logic. Provides operators a simple signal that scheduled cron execution is actively occurring in the environment.

| Property | Value |
|----------|-------|
| **Hook** | `tcm_async_test_heartbeat` (`AsyncHeartbeat::CRON_HOOK`) |
| **Schedule** | `tcm_every_minute` (60 s interval, registered via `cron_schedules` filter) |
| **Option written** | `tcm_async_test_last_run` (`AsyncHeartbeat::OPTION_NAME`) |
| **Option contents** | `unix_timestamp`, `datetime_utc`, `datetime_local`, `timezone`, `source` |
| **Init** | `AsyncHeartbeat::init()` called from `inc/loader.php` |

If `tcm_async_test_last_run` shows a timestamp older than ~90 seconds, scheduled events are not executing reliably in the current environment.

```bash
# Raw option read:
docker compose exec wordpress wp option get tcm_async_test_last_run --format=json

# Via cron inspection command:
docker compose exec wordpress wp tcm-cron status
```

### 18.3 Real Cron vs Pseudo-Cron

WordPress pseudo-cron fires scheduled events only when an HTTP request hits the site. In low-traffic or API-only environments this means events may execute late or miss their window entirely.

**Environment variable:** `TCM_DISABLE_WP_CRON`
**Handled in:** `inc/env.php`
**Effect:** Truthy values (`true`, `1`, `yes`, `on`) cause `inc/env.php` to define `DISABLE_WP_CRON = true`, which stops WordPress from spawning `wp-cron.php` on page loads. A system cron must then drive execution.

**Docker Compose passthrough:** `TCM_DISABLE_WP_CRON: ${TCM_DISABLE_WP_CRON:-false}` (defaults to `false`).

```bash
# .env to enable real cron mode:
TCM_DISABLE_WP_CRON=true
```

**Environment behavior summary:**

| Environment | `TCM_DISABLE_WP_CRON` | Cron behavior |
|-------------|----------------------|---------------|
| Local dev | `false` (default) | Pseudo-cron — fires on page loads |
| Staging / certification | `true` recommended | Requires system cron job |
| Production | `true` recommended | System cron ensures reliable timing |

**Ops runbook:** `themes/travel-concierge-me-theme/docs/dev-docs/2026-03-22-production-cron-setup.md`

### 18.4 Cron Health Verification

```bash
# Show cron mode + all TCM-managed events + heartbeat age:
docker compose exec wordpress wp tcm-cron status

# Filter to TBO post-book follow-up:
docker compose exec wordpress wp tcm-cron status --hook=tcm_tbo_post_book_detail_followup

# Manually run overdue events:
docker compose exec wordpress wp cron event run --due-now

# Expected log sequence after a successful TBO booking:
# [TBOBooking] 📋 Scheduled post-book BookingDetail follow-up in 120s ...
# ... (120 s later) ...
# [TBOBooking] 🔄 Post-book BookingDetail follow-up started ...
# [TBOBooking] ✅ Post-book BookingDetail follow-up successful ...

# Tail TBO booking logs:
docker logs travel-concierge-me-builder-wordpress-1 --tail 200 | grep "\[TBOBooking\]"
```

---

## 19. Guest-Name Validation Layers (TBO Feedback #13)

TBO requires that guest `FirstName` and `LastName` in every `/Book` request contain no digits, no unsupported special characters, and are between 3 and 25 characters. Validation is implemented at five independent layers so that an invalid name cannot reach the TBO API regardless of how the request originates.

### 19.1 Layer Stack

| Layer | File | Enforcement |
|-------|------|-------------|
| **JS (UX)** | `assets/scripts/modules/guestDetailsManager.js` — `validateGuestName()` | Min 2 chars, no digits, allowed charset (A–Z, Latin Extended, space, `-`, `'`); Spanish error messages |
| **HTML attr** | `blocks/src/blocks/tcm-guest-form/index.js` — TEMPLATE | `minLength: 2` on all firstName/lastName inputs |
| **PHP session** | `classes/Endpoints/BookingSession/Endpoint.php` — `validate_guest_details_schema()` | Min 2, max 25, no digits, charset check, all guests; returns `WP_Error` before writing session |
| **Provider normalization** | `classes/Providers/Tbo/TboHotelProvider.php` — `normalize_name()` | AsciiSlugger → digit strip → whitespace collapse → length clamp (pad to 3, truncate at 25) |
| **Provider guard** | `classes/Providers/Tbo/TboHotelProvider.php` — `validate_book_session()` | Min-length + digit check for all guests; last-resort HTTP 400 before any TBO API call |

### 19.2 Length Policy

| Layer | Min | Max | Notes |
|-------|-----|-----|-------|
| JS, HTML, PHP session | 2 | 25 | UX minimum; allows 2-char names (e.g. "Li") |
| TBO API (`normalize_name`) | 3 | 25 | TBO requirement; names shorter than 3 are padded with 'X' |
| Provider guard (`validate_book_session`) | 3 (`NAME_MIN_LENGTH`) | — | TBO constant; blocks any sub-3-char name after normalization |

### 19.3 Allowed Character Set

`/^[A-Za-z\u00C0-\u024F\s'\-]+$/` (JS) / `/^[A-Za-z\x{00C0}-\x{024F}\s'\-]+$/u` (PHP)

Allowed: ASCII letters, Latin Extended A+B (é, ñ, ü, ö, etc.), spaces, hyphens, apostrophes.  
Rejected at JS and PHP session layers: digits, `@`, `#`, `$`, and all other special characters.

**Note:** `normalize_name()` further converts accented characters to their ASCII equivalents (é→e, ñ→n) before sending to TBO. This is a TBO API constraint — not a data storage constraint.

### 19.4 Required Builds

After modifying any of the JS/block files, rebuild:
- `blocks/` — `npm run build` inside `blocks/`
- `assets/` — `npm run build` inside `assets/`
