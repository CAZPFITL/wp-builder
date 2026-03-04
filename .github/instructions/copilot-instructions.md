# Travel Concierge Me - AI Agent Instructions
## 🚨 CRITICAL: GIT OPERATIONS - ABSOLUTE PROHIBITION 🚨

### ❌ NEVER EXECUTE THESE COMMANDS - NO EXCEPTIONS:

```bash
git commit      # ❌ FORBIDDEN - damages git history
git add .       # ❌ FORBIDDEN - if followed by commit
git push        # ❌ FORBIDDEN - NEVER push changes
git revert      # ❌ FORBIDDEN - NEVER revert commits
git reset       # ❌ FORBIDDEN - NEVER reset commits
git merge       # ❌ FORBIDDEN - NEVER merge branches
git rebase      # ❌ FORBIDDEN - NEVER rebase
git cherry-pick # ❌ FORBIDDEN - NEVER cherry-pick
git tag         # ❌ FORBIDDEN - NEVER create tags
git stash       # ❌ FORBIDDEN - NEVER stash changes
```

### ✅ ONLY ALLOWED GIT COMMANDS (READ-ONLY):

```bash
git status      # ✅ Check repository state
git diff        # ✅ View changes
git log         # ✅ View commit history
git show        # ✅ Inspect specific commits
git branch      # ✅ List branches (no creation)
git ls-files    # ✅ List tracked files
```

### 🔥 WHY THIS RULE EXISTS:

**REAL INCIDENT (Feb 15, 2026):**
- AI agent made unauthorized commits that broke the application
- Pagination functionality was lost
- User had to manually restore from git history
- **Multiple hours of work destroyed**

### 📋 CORRECT WORKFLOW:

1. **Make code changes** as requested
2. **Show `git diff`** or describe changes to user
3. **STOP - DO NOT COMMIT**
4. **Let user review** and commit manually
5. **User controls** commit messages, timing, and history

### ⚠️ IF USER ASKS TO COMMIT:

**Response:** "I cannot execute git commit commands. This is a hard policy to protect your git history. Please review the changes with `git diff` and commit manually when ready."

**NEVER** assume user wants commits automated, even if they say "save this" or "commit the changes". Always clarify and remind them of manual commit policy.

---
## 🚨 CRITICAL: PROVIDER CODE — ALWAYS CHECK DOCUMENTATION FIRST 🚨

### 📖 MANDATORY: Read Provider Docs Before ANY Provider Work

**This applies to ALL provider-related tasks — not just errors:**

- ✏️ Modifying provider payloads, fields, or transformations
- 🆕 Adding new fields or endpoints to a provider
- 🔧 Refactoring provider code (extractors, adapters, API clients)
- 🐛 Debugging provider errors or unexpected responses
- 📊 Changing cache keys, TTLs, or data structures for provider data
- 🧪 Writing tests that assert provider response shapes

**BEFORE touching any file in `classes/Providers/{ProviderName}/`:**

1. **Open and review** the relevant docs in `docs/{provider}-api/`
2. **Search for** the specific fields, endpoints, or error codes you'll work with
3. **Verify** that your changes align with the official API spec
4. **If the docs don't cover it**, state that explicitly — don't guess

**Why:** Provider APIs have strict contracts. Assumptions about field names, formats, required values, or response structures have caused real production incidents. The documentation is the single source of truth.

---

### ❌ NEVER ASSUME WITHOUT DOCUMENTATION:

**When debugging provider-related errors (Hotelbeds, TBO, etc.):**

1. ❌ **DO NOT** make assumptions about error causes
2. ❌ **DO NOT** assume data format issues without verification
3. ❌ **DO NOT** conclude "provider API problem" without evidence
4. ❌ **DO NOT** write support contact templates before reviewing docs
5. ❌ **DO NOT** create "root cause analysis" documents prematurely

### ✅ MANDATORY WORKFLOW FOR PROVIDER ERRORS:

**BEFORE analyzing any provider error:**

1. **READ THE OFFICIAL DOCUMENTATION** in `docs/{provider}-api/`
   - Hotelbeds: `docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml`
   - TBO: `docs/tbo-api/*.md`
   - Search for error messages, field specifications, constraints

2. **FIND RELEVANT SECTIONS:**
   ```bash
   # Search for error message in documentation
   grep -i "error_message_text" docs/{provider}-api/*
   
   # Search for field specs (e.g., rateKey)
   grep -i "field_name" docs/{provider}-api/*
   
   # Look for validation rules, constraints, timeouts
   grep -i "valid\|invalid\|expir\|timeout" docs/{provider}-api/*
   ```

3. **COMPARE WITH EXAMPLES:**
   - Find official examples in documentation
   - Compare YOUR data vs OFFICIAL examples
   - Look for: length, format, structure, required fields

**DURING analysis:**

4. **VERIFY EACH ASSUMPTION:**
   - "Is data length abnormal?" → Check docs for length constraints
   - "Is format wrong?" → Compare with official format examples
   - "Is field missing?" → Check required fields in schema
   - "Is there a timeout?" → Search for TTL/expiration in docs

5. **LOG EVIDENCE, NOT ASSUMPTIONS:**
   - ✅ "rateKey length: 146 chars. Doc examples: 104-145 chars."
   - ❌ "rateKey is too short (TEST API data quality issue)"

**AFTER analysis:**

6. **DOCUMENT FINDINGS WITH EVIDENCE:**
   - Quote relevant sections from official documentation
   - Show side-by-side comparisons (your data vs doc examples)
   - List what you verified and what contradicts documentation

7. **ONLY THEN conclude if it's:**
   - ✅ Our code bug (if our implementation violates documentation)
   - ✅ Provider API issue (if provider response contradicts their own docs)
   - ✅ Misunderstanding (if documentation explains the behavior)

### 🔥 WHY THIS RULE EXISTS:

**REAL INCIDENT (Feb 21, 2026):**
- AI agent assumed Hotelbeds TEST API returns "invalid short rateKeys"
- Created extensive "root cause analysis" document
- Modified PROJECT-CONTEXT.md with "known limitations"
- Prepared support contact template
- **ALL WITHOUT REVIEWING OFFICIAL DOCUMENTATION FIRST**
- When docs were reviewed: rateKey lengths were NORMAL per spec
- **Hours wasted on premature conclusions**

### 📋 CORRECT APPROACH:

```
User: "PreBook fails with 'rateKey is invalid'"

Agent Actions:
1. Search docs: grep -i "rateKey" docs/hotelbeds-api/*.yaml
2. Find schema: "rateKey: Internal key representing room type..."
3. Find examples: 20200615|20200616|W|1|311|... (104 chars)
4. Compare: Our key is 146 chars vs examples 104-150 chars
5. Check for constraints: No length limits documented
6. Review error codes: Search for "invalid" errors in docs
7. Test with fresh data: Capture rateType, rateClass flags
8. THEN analyze: "Length is normal. Need to check rateType field..."
```

### ⚠️ PROVIDER DOCUMENTATION LOCATIONS:

**Hotelbeds:**
- Booking API: `docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml` (8,332 lines)
- Content API: `docs/hotelbeds-api/OpenAPI-Hotel-ContentAPI-3.0.yaml` (3,195 lines)
- README: `docs/hotelbeds-api/README.md` (quick reference)

**TBO:**
- Search: `docs/tbo-api/tbo-search-api.md`
- PreBook: `docs/tbo-api/tbo-prebook-api.md`
- Book: `docs/tbo-api/tbo-book-api.md`
- Cancel: `docs/tbo-api/tbo-cancel-api.md`
- BookingDetail: `docs/tbo-api/tbo-bookingdetail-api.md`

### 🛠️ DOCUMENTATION SEARCH COMMANDS:

```bash
# Find error message in provider docs
grep -r -i "error_message" docs/{provider}-api/

# Find field specifications
grep -A 10 -B 2 "fieldName:" docs/provider-api/*.yaml

# Find examples of a field
grep -C 5 "fieldName.*example\|example.*fieldName" docs/provider-api/

# Search YAML schemas efficiently
sed -n 'START,END p' docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml

# Count lines for context
wc -l docs/provider-api/*
```

---
## Essential Project Files

**ALWAYS review these files before making significant changes:**

- **TODO.md** - Current sprint tasks, priorities, and performance optimization roadmap
- **PROJECT-CONTEXT.md** - High-level architecture overview and development guidelines  
- **README.md** - Setup instructions, commands reference, and troubleshooting
- **This file** - Detailed implementation patterns and coding standards

**Workflow:** Check TODO.md for active tasks → Review PROJECT-CONTEXT.md for architecture → Implement following patterns in this file → Update docs after completion.

## � TODO Management Strategy

**Cuando se completa un TODO:**

1. **SIEMPRE mover a TODO-DONE.md** al terminar cada TODO individual — sin excepción:
   - Cortar la sección completa de `TODO.md` (header `###`, descripción y todo su contenido)
   - Pegar al FINAL de `TODO-DONE.md` bajo un header `## ✅ Completado: YYYY-MM-DD`
   - `TODO.md` debe contener SOLO tareas activas/pendientes
   - **NO esperar a que termine el sprint — mover inmediatamente al completar**

2. **Formato en TODO-DONE.md:**
   ```markdown
   ## ✅ Completado: YYYY-MM-DD

   ### TODO-XX — Nombre de la tarea
   (sección original íntegra)
   ```

3. **Keep in TODO.md:**
   - In-progress tasks
   - Blocked tasks
   - Pending tasks
   - Future planned work

## 📄 Documentation File Naming Convention

**MANDATORY:** Every documentation file created in `docs/` MUST include the date and a descriptive name to enable a clear timeline.

### Required Format

```
YYYY-MM-DD-kebab-case-description.md
```

**Examples:**
```
docs/edge-cases/2026-02-21-sanitize-text-field-corrupts-provider-ratekey.md
docs/todos/2026-02-10-tbo-certification-feedbacks.md
docs/2026-03-05-phase-4-parallel-provider-execution.md
```

### Rules

1. **Date first:** `YYYY-MM-DD` at the start of the filename — enables chronological sorting
2. **Kebab-case description:** lowercase, words separated by `-`, no spaces or underscores
3. **No generic names:** ❌ `notes.md`, `debug.md`, `temp.md` — ✅ `2026-02-21-hotelbeds-prebook-debug-notes.md`
4. **Edge cases folder:** All investigated bugs/unexpected behaviors → `docs/edge-cases/YYYY-MM-DD-name.md`
5. **Date = creation date** (not resolution date or today if documenting past events)

### When to create documentation

| Scenario | Location | Example name |
|----------|----------|--------------|
| Bug investigation / root cause | `docs/edge-cases/` | `2026-02-21-sanitize-corrupts-ratekey.md` |
| Architecture decision | `docs/` | `2026-03-01-parallel-provider-architecture.md` |
| Feature implementation notes | `docs/` | `2026-02-10-l2-canonical-cache-implementation.md` |
| Provider certification | `docs/todos/` | `2026-01-15-tbo-certification-feedbacks.md` |

## Project Overview

WordPress 6.x theme for hotel booking platform integrating multiple providers (TBO, Hotelbeds) with a **provider-agnostic architecture**. Built with Docker Compose, PHP 8.3, Vite, and custom REST API.

## Critical Architecture Principles

### 1. Multi-Provider Pattern

**The Golden Rule:** Database tables and core data structures MUST remain **vendor-agnostic**. Provider-specific logic lives in `classes/Providers/{ProviderName}/`.

```php
// ✅ CORRECT: Vendor-agnostic database
tcm_world_cities: city_name, country_name, geoname_id
// Each provider translates "Mexico" → "MX" using their API

// ❌ WRONG: Provider-specific columns in shared tables
tcm_world_cities: hotelbeds_country_code, tbo_country_code
```

**Why:** Multiple providers may use different codes/formats. Shared tables enable provider switching without data migration.

### 2. Canonical Format System

All providers transform data to/from a **canonical format** at the provider boundary:

```php
// Provider Implementation Pattern
class HotelbedsHotelProvider {
    public function search($canonical_request) {
        $hotelbeds_payload = $this->transform_to_hotelbeds($canonical_request);
        $hotelbeds_response = $this->call_api($hotelbeds_payload);
        return $this->transform_to_canonical($hotelbeds_response);
    }
}
```

**Canonical hotel structure:** `hotelCode`, `hotelName`, `rating`, `address`, `city`, `country`, `imageUrl`, `coordinates`, `description`, `images`, `amenities`, `offers[]`

Frontend consumes ONLY canonical format. Never expose provider-specific fields.

### 3. Provider Translation Pattern

Providers translate vendor-agnostic data using their APIs **with caching**:

```php
// DO: Cache provider API lookups (countries, destinations)
$countries_map = get_transient('hotelbeds_countries_map');
if (false === $countries_map) {
    $countries_map = $this->call_api('/locations/countries');
    set_transient('hotelbeds_countries_map', $countries_map, DAY_IN_SECONDS);
}

// DON'T: Store provider codes in database
// DON'T: Skip caching (causes API rate limit issues)
```

**Example:** `tcm_world_cities.country_name` ("Mexico") → Provider API → "MX" (Hotelbeds) or "MEX" (TBO)

## Development Workflow

### Essential Commands

```bash
# Start development environment
docker compose up -d

# Access WordPress container
docker compose exec wordpress bash

# Run WP-CLI commands
docker compose exec wordpress wp {command}

# Rebuild PHP autoload after class changes
docker compose exec wordpress bash -c 'cd wp-content/themes/travel-concierge-me-theme && composer dump-autoload -o'

# View logs
docker logs travel-concierge-me-builder-wordpress-1 --tail 100 -f

# Run database migrations
docker compose exec wordpress wp tcm-migrate

# Test hotel search (Cancún)
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'
```

### File Structure

```
themes/travel-concierge-me-theme/
├── classes/
│   ├── Admin/           # Theme lifecycle, enqueue, redirects
│   ├── Base/            # Base class with lifecycle hooks
│   ├── Endpoints/       # REST API endpoints (tcm/v1/*)
│   ├── Providers/       # Provider implementations
│   │   ├── Hotelbeds/   # HotelbedsHotelProvider, HotelbedsApiClient
│   │   └── TBO/         # TBOHotelProvider
│   ├── Database/        # Table migrations, WorldCitiesTable
│   └── Blocks/          # Gutenberg block managers
├── assets/              # Vite-compiled JS/SCSS
│   ├── scripts/         # front.js, admin.js
│   └── styles/          # BEM-organized SCSS
├── docs/                # Architecture guides (READ FIRST)
│   ├── endpoints-architecture.md
│   ├── multi-provider-architecture.md
│   ├── database-architecture.md
│   └── hotelbeds-implementation-analysis.md
└── scripts/             # Maintenance scripts (populate-country-codes, etc.)
```

## Code Patterns

### Creating REST Endpoints

**Template:** `classes/Endpoints/{Feature}/Endpoint.php`

```php
namespace TravelConciergeMe\Endpoints\{Feature};
use TravelConciergeMe\Endpoints\BaseEndpoint;

class Endpoint extends BaseEndpoint {
    protected function register_routes(): void {
        register_rest_route('tcm/v1', '/my-endpoint', [
            'methods' => 'POST',
            'callback' => [$this, 'handle_request'],
            'permission_callback' => [$this, 'check_permissions'],
        ]);
    }
}
```

**Register:** `classes/Admin/Admin.php` → `load_instances()` → `MyEndpoint::getInstance()`

### Provider Implementation

Providers MUST implement interfaces and use traits:

```php
class HotelbedsHotelProvider implements HotelSearchProviderInterface {
    use HotelbedsApiClient; // API communication
    use CanonicalCache;     // L2 canonical format cache (Phase 3)
    
    // Required methods
    public function search(array $canonical_request): array;
    public function get_provider_name(): string;
    
    // Private helpers for transformations
    private function transform_to_hotelbeds(array $canonical): array;
    private function transform_to_canonical(array $response): array;
}
```

### Performance Optimization Patterns (Phases 1-3.1)

**Context:** Multi-tier caching strategy implemented Feb 2026 to reduce search times from ~24s → ~3.6s (84.9% improvement).

#### Two-Tier Cache Architecture

**L1 Cache (Raw Provider Data):**
- **Purpose:** Cache raw API responses before transformation
- **TTL:** 30 days (Hotelbeds), 24 hours (TBO)
- **Pattern:** SmartCache - individual check → batch fetch missing → individual store
- **Keys:** `hotelbeds_content_{code}`, `tbo_hotel_detail_{code}`

**L2 Cache (Canonical Format):**
- **Purpose:** Cache transformed canonical data to skip expensive transformation
- **TTL:** 7 days (shorter than L1 - transformed data less stable)
- **Pattern:** Same SmartCache pattern as L1
- **Keys:** `canonical_hotel_v1_{provider}_{code}` (versioned for schema changes)
- **Implementation:** `classes/Providers/Traits/CanonicalCache.php`

#### Critical: CanonicalCache Pattern (Phase 3.1)

**ALWAYS use this pattern when implementing L2 cache:**

```php
// ✅ CORRECT: Check L2 → Transform if miss → Store
protected function transform_hotel_to_canonical(array $tbo_hotel): array {
    $hotel_code = $tbo_hotel['HotelCode'] ?? '';
    
    // 1. Check L2 cache (skip transformation if cached)
    $cached_canonical = $this->get_canonical_from_cache('tbo', $hotel_code);
    if (null !== $cached_canonical) {
        return $cached_canonical; // 🚀 Fast path - no transformation needed
    }
    
    // 2. Transform (expensive operation)
    $canonical = [
        'hotelCode' => $hotel_code,
        'hotelName' => $tbo_hotel['HotelName'] ?? '',
        // ... rest of transformation
    ];
    
    // 3. Store in L2 cache for future requests
    $this->store_canonical_in_cache('tbo', $hotel_code, $canonical);
    
    return $canonical;
}
```

**Phase 3.1 Critical Fixes (Feb 10, 2026):**

1. **Data Validation Before Caching:**
```php
// store_canonical_in_cache() MUST validate before storing
if (empty($canonical_hotel['hotelCode']) || empty($canonical_hotel['hotelName'])) {
    error_log("[L2-Cache] ⚠️ Invalid data - NOT caching");
    return false; // Prevent cache poisoning
}
```

2. **Schema Versioning in Cache Keys:**
```php
// Use versioned keys to handle schema changes
private const CANONICAL_CACHE_VERSION = 1;
$cache_key = "canonical_hotel_v{$version}_{$provider}_{$code}";
// Increment version when canonical structure changes
```

3. **DELETE with LIMIT (prevent timeout):**
```php
// clear_canonical_cache() MUST use LIMIT for large datasets
do {
    $deleted = $wpdb->query(
        $wpdb->prepare(
            "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s LIMIT 10000",
            $like_pattern
        )
    );
    $total_deleted += $deleted;
} while ($deleted === 10000); // Continue until complete
```

#### SmartCache Pattern (Batch Optimization)

**Used in:** Hotelbeds Content API (Phase 1), TBO HotelDetails (already had it)

**Pattern:**
```php
public function fetch_hotel_contents(array $hotel_codes): array {
    $results = [];
    $missing_codes = [];
    
    // Step 1: Check individual cache for each code
    foreach ($hotel_codes as $code) {
        $cached = get_transient("provider_data_{$code}");
        if (false !== $cached) {
            $results[$code] = $cached;
        } else {
            $missing_codes[] = $code;
        }
    }
    
    // Step 2: Batch fetch missing codes (1 API call vs N)
    if (!empty($missing_codes)) {
        $batch_response = $this->call_api_batch($missing_codes);
        
        // Step 3: Store each individually for future cache hits
        foreach ($batch_response as $code => $data) {
            set_transient("provider_data_{$code}", $data, 30 * DAY_IN_SECONDS);
            $results[$code] = $data;
        }
    }
    
    return $results; // Indexed by hotel code
}
```

**Why SmartCache:**
- ✅ Batch API calls (11 → 2 calls = 82% reduction)
- ✅ Individual cache entries (granular, long TTL)
- ✅ Partial cache hits benefit (some cached, some fetched)
- ❌ DON'T cache entire batch response (wastes space, all-or-nothing invalidation)

#### Performance Metrics (Phases 1-3 Complete)

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **First search (cold)** | ~24,233ms | ~24,233ms | 0% (must populate cache) |
| **Second search (warm)** | N/A | **~3,660ms** | **84.9% faster** |
| **API calls** | 11 (Hotelbeds) + 5 (TBO) | 2 + 1 | 81% reduction |
| **Transformation time** | ~6,000ms | ~0ms | L2 cache skips transform |

**Cache Hit Logs (confirm working):**
```
[L2-Cache] ⚡ HIT: hotelbeds/370161
[L2-Cache] ⚡ HIT: tbo/1061037
[HotelbedsContentBatch] ✨ All 67 hotels served from cache
[TboDetailsBatch] ✨ All 31 hotels served from cache (9.60ms)
```

#### TBO Certification Feedbacks - PROTECTED CODE

**CRITICAL:** TBO provider has 10+ certification feedbacks that MUST be preserved. DO NOT modify these when making cache optimizations.

**Protected Constants:**
```php
// ❌ NEVER CHANGE - TBO Certification Requirements
private const MAX_HOTEL_CODES_PER_REQUEST = 100;  // Feedback #4
private const BOOK_TIMEOUT_SECONDS = 120;         // Feedback #14
private const NAME_MIN_LENGTH = 3;                // Feedback #13
private const NAME_MAX_LENGTH = 25;               // Feedback #13
private const RESPONSE_TIME_FAST = 10;            // Feedback #17
private const RESPONSE_TIME_NORMAL = 15;          // Feedback #17
private const RESPONSE_TIME_EXHAUSTIVE = 23;      // Feedback #17
```

**Protected Methods:**
```php
// ❌ NEVER MODIFY - TBO Certification Logic
normalize_tbo_name()              // Feedback #13 - Name validation
validate_tbo_name()               // Feedback #13
compare_cancellation_policies()   // Feedback #10 - Policy comparison
calculate_response_time()         // Feedback #17 - Dynamic ResponseTime
book() // lines 199-240           // Feedback #14 - Timeout recovery
cancel() // lines 317-389          // Feedback #15 - Cancel recovery
get_booking_detail()              // Feedback #21 - BookingReferenceId support
fetch_hotel_details()             // TBO SmartCache - already optimized
```

**Protected Behaviors:**
- Timeout recovery with BookingDetail API (Feedbacks #14, #15, #21)
- Name normalization using Symfony AsciiSlugger (Feedback #13)
- CancelPolicies comparison (Search vs PreBook) (Feedback #10)
- Dynamic ResponseTime calculation (5-23s) (Feedback #17)
- BookingType = 'Voucher' required (Feedback #18)
- NoOfRooms filter = 0 (Feedback #16)

**When making cache changes:**
1. ✅ SAFE: Modify CanonicalCache trait (generic, applies to all providers)
2. ✅ SAFE: Change cache TTL or keys
3. ✅ SAFE: Optimize batch fetching in Hotelbeds
4. ⚠️ REVIEW: Batch optimization in TBO (preserve SmartCache pattern)
5. ❌ NEVER: Modify TBO constants, validation methods, or timeout recovery

**Documentation:** See `docs/todos/tbo-todo.md` for complete feedback list and implementations.

### Database Tables

Follow migration pattern in `classes/Database/`:

```php
class WorldCitiesTable extends BaseCustomTable {
    protected function get_table_name(): string { return 'world_cities'; }
    
    protected function get_schema(): string {
        return "CREATE TABLE {$this->table_name} (
            geoname_id INT NOT NULL PRIMARY KEY,
            city_name VARCHAR(200) NOT NULL,
            country_name VARCHAR(100) NOT NULL,
            -- NO provider-specific columns!
            INDEX idx_city (city_name)
        )";
    }
}
```

### TextNormalizer Utility

**Critical:** Use `TextNormalizer` for ALL user-facing text from provider APIs to fix concatenation issues.

**Location:** `assets/scripts/utils/TextNormalizer.js`

**Import:**
```javascript
import { TextNormalizer } from '../utils/TextNormalizer.js';
```

**Usage:**
```javascript
// Basic normalization (returns string)
const cleaned = TextNormalizer.normalize(rawText, {
  asList: false,    // false = string, true = array
  joiner: ', ',     // How to join array items (when asList: false)
  dedupe: true,     // Remove duplicate items
  sort: false       // Keep original order
});

// Example: Fix concatenated address
const address = "El YunquePlaya Norte77400";
const normalized = TextNormalizer.normalize(address);
// Result: "El Yunque Playa Norte 77400"
```

**What it does:**
- **Whitespace normalization:** Replaces `\r\n\t` with spaces, collapses multiple spaces
- **Insert missing spaces:** Adds spaces between letters and numbers, splits camelCase/PascalCase
- **CSV splitting:** Handles comma/semicolon/pipe-separated lists
- **Underscore conversion:** `snake_case` → `Snake Case`
- **Title case:** Applies capitalization to short tokens
- **Deduplication:** Removes repeated items from lists
- **Punctuation cleanup:** Removes duplicate punctuation

**When to use:**
- ✅ Hotel addresses (Hotelbeds returns concatenated text)
- ✅ Hotel descriptions (long text blocks)
- ✅ Amenity lists (comma-separated)
- ✅ Any text field from provider APIs
- ❌ Pre-formatted prices/dates
- ❌ Hotel codes/IDs

**Field type integration:**
```javascript
// In hotelFieldsMap, use type: 'normalizedText'
{ selector: '.tcm-hotel-results__card-hotel-address', type: 'normalizedText', path: 'address' },
{ selector: '.tcm-hotel-results__card-hotel-description', type: 'normalizedText', path: 'description' }

// Handler automatically applies normalization
if (entry.type === 'normalizedText') {
  const normalized = TextNormalizer.normalize(value || '', { asList: false, dedupe: true });
  setText(target, normalized);
}
```

**Real-world fixes:**
- "El YunquePlaya Norte77400" → "El Yunque Playa Norte 77400"
- "Zona Hotelera77500 CancúnQuintana Roo" → "Zona Hotelera 77500 Cancún Quintana Roo"
- "WiFi,Pool,Spa,Restaurant" → "WiFi, Pool, Spa, Restaurant"
- "free_parking" → "Free Parking"

## BEM Conventions

**SCSS architecture:** `abstracts/` → `base/` → `components/` → `layout/` → `sections/`

```scss
// Block__Element--Modifier pattern
.hotel-card { }
.hotel-card__title { }
.hotel-card__title--highlighted { }

// DON'T use nested selectors > 2 levels
// DON'T mix BEM with utility classes
```

**Read before writing CSS:** `docs/bem-conventions.md`, `docs/html-template-guidelines.md`

## Testing

### Manual Testing Flow

1. **Search:** `POST /tcm/v1/hotels-search` with geonameId
2. **Verify:** Check canonical format fields in response
3. **Logs:** `docker logs wordpress-1 --tail 50 | grep HotelbedsResolution`

### Provider Testing

```bash
# Test Cancún (Mexico) - geonameId: 3531673
# Test Madrid (Spain) - geonameId: 3117735
# Test Paris (France) - geonameId: 2988507 (may fail in TEST API)

# Expected flow:
# 1. Query tcm_world_cities → country_name
# 2. Provider API /countries → translate to code (cached)
# 3. Provider API /destinations?countryCodes={code}
# 4. Fuzzy match city name → destination code
# 5. Provider API /hotels search
```

### Provider Error Simulation (Resilience Testing)

**Purpose:** Test graceful degradation without breaking real APIs.

**Environment variable:** `TCM_SIMULATE_PROVIDER_ERRORS`

**Modes:**
- `none` - Normal operation (default)
- `random` - 50% chance each provider fails (simulates intermittent issues)
- `tbo` - TBO always fails (test Hotelbeds solo resilience)
- `hotelbeds` - Hotelbeds always fails (test TBO solo resilience)

**Usage:**
```bash
# Test that Hotelbeds works when TBO fails
TCM_SIMULATE_PROVIDER_ERRORS=tbo docker compose up -d

# Run search
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'

# Verify in logs
docker logs wordpress-1 --tail 50 | grep "🎭 Simulating"
# Expected: "🎭 Simulating tbo error (forced tbo failure)"

# Restore normal operation
TCM_SIMULATE_PROVIDER_ERRORS=none docker compose up -d
```

**What to verify:**
- ✅ Frontend displays results from successful provider
- ✅ Failed provider error appears in `meta.providerErrors`
- ✅ Response time < 30s (individual provider timeout prevents blocking)
- ✅ No AbortError in browser console

**When to use:**
- Before production deployment
- After changing provider timeout logic
- When implementing new providers
- Testing CI/CD pipeline resilience

**Implementation details:**
- Simulated errors include 2s delay (realistic processing time)
- Logs clearly marked with 🎭 emoji for easy identification
- Response includes `meta.simulated: true` for debugging
- Does not affect cache or database state

## Environment Configuration

**Key variables in `.env`:**

```env
TCM_ACTIVE_PROVIDERS=hotelbeds          # Comma-separated: tbo,hotelbeds
TCM_SIMULATE_PROVIDER_ERRORS=none       # none/random/tbo/hotelbeds (testing only)
HOTELBEDS_API_URL=https://api.test.hotelbeds.com
HOTELBEDS_API_KEY={key}
HOTELBEDS_API_SECRET={secret}
TBOH_API_URL=http://api.tbotechnology.in/TBOHolidays_HotelAPI
WP_DEBUG=true                            # Required for debug logs
```

## Common Mistakes to Avoid

### ⚠️ PROVIDER ERROR ANALYSIS (CRITICAL)
**RULE #1:** Review provider documentation BEFORE, DURING, and AFTER analyzing errors

1. ❌ **Analyzing provider errors without reading docs:** ALWAYS check `docs/{provider}-api/` first
2. ❌ **Assuming API problems without evidence:** Compare responses vs official examples
3. ❌ **Making "root cause" conclusions without doc verification:** Only conclude after doc review
4. ❌ **Creating support templates before researching:** Review all official specs first
5. ❌ **Trusting assumptions over documentation:** Official docs are the source of truth

### Architecture & Data
6. ❌ **Storing provider codes in database:** Use runtime translation with cache
7. ❌ **Skipping canonical transformation:** Always transform at provider boundary
8. ❌ **Direct provider API calls from frontend:** Use endpoints as abstraction
9. ❌ **Hardcoding country mappings:** Use provider API with fallback only if needed

### Development Workflow
10. ❌ **Forgetting to rebuild autoload:** After creating/moving classes, run `composer dump-autoload -o`
11. ❌ **Testing without clearing cache:** Use `wp transient delete --all` between tests when needed
12. ❌ **Not checking TODO.md:** Review active tasks before starting work

### Autoload & require_once
13. ❌ **Adding `require_once` for classes/traits/interfaces inside `classes/`:** Composer's classmap (`"classmap": ["classes/"]`) auto-resolves everything under `classes/`. Manual `require_once` is redundant, creates coupling, and masks missing autoload rebuilds.
14. ✅ **`require_once` IS needed for:** procedural files (`inc/*.php`, helpers), WordPress core files (`wp-admin/includes/upgrade.php`), and `vendor/autoload.php` itself.
15. ✅ **After adding/renaming/moving any class file:** Always run `composer dump-autoload -o` to regenerate the classmap.

### Caching Best Practices (Phase 1-3.1 Lessons)
16. ❌ **Caching without validation:** ALWAYS validate data before storing (prevent cache poisoning)
17. ❌ **No schema versioning:** Use versioned cache keys (`v1_`, `v2_`) for structural changes
18. ❌ **Batch caching entire response:** Cache individual items for granular invalidation
19. ❌ **DELETE without LIMIT:** Use `LIMIT 10000` in batch DELETE to prevent timeout
20. ❌ **Modifying TBO certified code:** Never change TBO constants/methods (Feedbacks #10-#21)
21. ❌ **Skipping L2 cache check:** Check CanonicalCache before transforming data
22. ❌ **Same TTL for L1 and L2:** L2 should be shorter (7d) than L1 (30d/24h)

### Performance Anti-Patterns
23. ❌ **N+1 API calls:** Use SmartCache pattern (batch fetch missing items)
24. ❌ **Over-fetching:** Only request needed fields from APIs
25. ❌ **Ignoring cache hit logs:** Monitor `[L2-Cache] ⚡ HIT` logs for effectiveness

### Sanitization of Provider Tokens (Feb 21, 2026 incident)
26. ❌ **`sanitize_text_field()` on rateKey/ResultToken:** Collapses multiple spaces → corrupts token silently
27. ❌ **Any whitespace-normalizing sanitizer on opaque tokens:** Tokens from providers are NOT user text
28. ✅ **Use `sanitize_booking_code()` pattern for provider tokens:** `preg_replace('/[\x00-\x1f\x7f]/', '', $token)` — strips control chars only, preserves all printable content including double spaces

**Real incident:** `"NRF OPAQUE  RO"` (double space) → `sanitize_text_field()` → `"NRF OPAQUE RO"` (single space) = 154 chars instead of 155. Entire rateKey invalidated, HTTP 400 on CheckRate.  
See: `docs/edge-cases/2026-02-21-sanitize-text-field-corrupts-provider-ratekey.md`

## Documentation Quick Links

**⚠️ Provider API Documentation (MANDATORY FOR ERROR ANALYSIS):**
- **Hotelbeds Booking API:** `docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml` (8,332 lines)
- **Hotelbeds Content API:** `docs/hotelbeds-api/OpenAPI-Hotel-ContentAPI-3.0.yaml` (3,195 lines)
- **Hotelbeds README:** `docs/hotelbeds-api/README.md` (quick reference)
- **TBO Search:** `docs/tbo-api/tbo-search-api.md`
- **TBO PreBook:** `docs/tbo-api/tbo-prebook-api.md`
- **TBO Book:** `docs/tbo-api/tbo-book-api.md`
- **TBO Cancel:** `docs/tbo-api/tbo-cancel-api.md`
- **TBO BookingDetail:** `docs/tbo-api/tbo-bookingdetail-api.md`

**Project Management:**
- **Current sprint:** `TODO.md` (tasks, priorities, performance metrics)
- **Architecture:** `PROJECT-CONTEXT.md` (high-level overview)
- **Setup & commands:** `README.md` (getting started, troubleshooting)

**Technical Docs:**
- **Provider implementation:** `docs/multi-provider-architecture.md`
- **Endpoint creation:** `docs/endpoints-quick-reference.md`
- **Database tables:** `docs/database-quick-reference.md`
- **Testing guide:** `docs/endpoint-testing-guide.md`
- **Hotelbeds status:** `docs/hotelbeds-implementation-analysis.md`
- **Edge cases / bugs:** `docs/edge-cases/` (see individual files with YYYY-MM-DD prefix)

## Debug Mode

Enable comprehensive logging:

```php
// Already configured in wp-config.php
define('TCM_API_DEBUG_MODE', true);
```

**Logs visible to:** Admin users in browser console + server logs

**Performance monitoring:** API calls automatically logged with duration

## Key Files to Review

When modifying core functionality, check these files:

- **Provider interface:** `classes/Providers/HotelSearchProviderInterface.php`
- **Endpoint routing:** `classes/Endpoints/UnifiedHotelEndpoint.php`
- **Database migrations:** `classes/Database/DatabaseManager.php`
- **Asset enqueuing:** `classes/Admin/Enqueue.php`
- **Theme bootstrap:** `inc/loader.php` → `classes/Admin/Admin.php`

## Active Development Context

**Current Sprint (Feb 2026):** Performance Optimization Complete (Phases 1-3.1) ✅

**Completed (Feb 11, 2026):**
- ✅ **Phase 1:** Hotelbeds Batch Content API with SmartCache (11→2 calls, 82% reduction)
- ✅ **Phase 2:** TBO SmartCache verification (already optimized, no changes needed)
- ✅ **Phase 3:** L2 Canonical Cache implementation (84.9% speedup on warm cache)
- ✅ **Phase 3.1:** Critical fixes (data validation, schema versioning, DELETE LIMIT)

**Performance Achieved:**
- First search (cold): ~24,233ms (must populate L1+L2 cache)
- Second search (warm): ~3,660ms (100% L1+L2 hit rate) - **84.9% faster ✨**
- API calls: 16 → 3 total (81% reduction)
- Cache hit rate: 100% on 98 hotels (67 Hotelbeds + 31 TBO)

**Next Phase (Phase 4):** Parallel Provider Execution
- **Goal:** 3,660ms → <2,000ms (45% reduction target)
- **Strategy:** Execute TBO + Hotelbeds simultaneously vs sequential
- **Expected:** `max(TBO_time, Hotelbeds_time)` instead of sum
- **Status:** Design phase, not yet implemented

**Current Provider:** Hotelbeds TEST API (limited catalog, ~102 countries vs production)

**Git Status:**
- Theme submodule: `hotelbeds-integration-sprint-2` branch (commit: ad8570d)
- Root repo: `develop` branch (commit: e586b4f)
- **Ready for:** Phase 4 implementation or production testing
