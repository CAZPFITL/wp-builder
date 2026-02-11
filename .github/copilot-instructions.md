# Travel Concierge Me - AI Agent Instructions

## Essential Project Files

**ALWAYS review these files before making significant changes:**

- **TODO.md** - Current sprint tasks, priorities, and performance optimization roadmap
- **PROJECT-CONTEXT.md** - High-level architecture overview and development guidelines  
- **README.md** - Setup instructions, commands reference, and troubleshooting
- **This file** - Detailed implementation patterns and coding standards

**Workflow:** Check TODO.md for active tasks → Review PROJECT-CONTEXT.md for architecture → Implement following patterns in this file → Update docs after completion.

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

## Environment Configuration

**Key variables in `.env`:**

```env
TCM_ACTIVE_PROVIDERS=hotelbeds          # Comma-separated: tbo,hotelbeds
HOTELBEDS_API_URL=https://api.test.hotelbeds.com
HOTELBEDS_API_KEY={key}
HOTELBEDS_API_SECRET={secret}
TBOH_API_URL=http://api.tbotechnology.in/TBOHolidays_HotelAPI
WP_DEBUG=true                            # Required for debug logs
```

## Common Mistakes to Avoid

### Architecture & Data
1. ❌ **Storing provider codes in database:** Use runtime translation with cache
2. ❌ **Skipping canonical transformation:** Always transform at provider boundary
3. ❌ **Direct provider API calls from frontend:** Use endpoints as abstraction
4. ❌ **Hardcoding country mappings:** Use provider API with fallback only if needed

### Development Workflow
5. ❌ **Forgetting to rebuild autoload:** After creating/moving classes, run `composer dump-autoload -o`
6. ❌ **Testing without clearing cache:** Use `wp transient delete --all` between tests when needed
7. ❌ **Not checking TODO.md:** Review active tasks before starting work

### Caching Best Practices (Phase 1-3.1 Lessons)
8. ❌ **Caching without validation:** ALWAYS validate data before storing (prevent cache poisoning)
9. ❌ **No schema versioning:** Use versioned cache keys (`v1_`, `v2_`) for structural changes
10. ❌ **Batch caching entire response:** Cache individual items for granular invalidation
11. ❌ **DELETE without LIMIT:** Use `LIMIT 10000` in batch DELETE to prevent timeout
12. ❌ **Modifying TBO certified code:** Never change TBO constants/methods (Feedbacks #10-#21)
13. ❌ **Skipping L2 cache check:** Check CanonicalCache before transforming data
14. ❌ **Same TTL for L1 and L2:** L2 should be shorter (7d) than L1 (30d/24h)

### Performance Anti-Patterns
15. ❌ **N+1 API calls:** Use SmartCache pattern (batch fetch missing items)
16. ❌ **Over-fetching:** Only request needed fields from APIs
17. ❌ **Ignoring cache hit logs:** Monitor `[L2-Cache] ⚡ HIT` logs for effectiveness

## Documentation Quick Links

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
