# TODO - Travel Concierge Me

## 🚀 Performance Optimization Sprint - PHASES 1-3 ✅ COMPLETADO

### ✅ Phase 1: Hotelbeds Batch Content API con SmartCache (**Feb 11, 2026**)
**Objetivo:** Reducir N+1 problem (1 Booking + 10 Content individual → 1 Booking + 1 Content batch)

**Implementación:**
- [x] Crear método `get_hotels_content_batch()` en HotelbedsApiClient.php
- [x] Modificar `transform_hotelbeds_to_canonical()` para usar batch
- [x] Implementar Smart Cache: individual cache (30d) + batch fetch missing items

**Resultados:**
- **API calls:** 11 → 2 (82% reducción)
- **First search:** ~10.8s | **Cached search:** ~3.9s (100% Content cache hit)
- **Batch efficiency:** 67 hotels en 1 API call vs 67 individuales

**Archivos:** HotelbedsApiClient.php (líneas 289-366), HotelbedsHotelProvider.php

---

### ✅ Phase 2: TBO SmartCache Pattern (**Feb 11, 2026**)
**Objetivo:** Aplicar mismo patrón SmartCache a TBO HotelDetails

**Hallazgo:** ✅ **YA IMPLEMENTADO** - TBO ya tenía SmartCache desde antes

**Código actual:**
- `fetch_hotel_details()` en TboHotelProvider.php (líneas 1038-1150)
- SmartCache: individual cache check → batch fetch missing (max 30/request) → store individual
- TTL: 24h, Logs: "All 31 hotels served from cache (9.60ms)"

**Resultado:** TBO batch ya optimizado, no requiere cambios

---

### ✅ Phase 3: L2 Canonical Cache (**Feb 11, 2026**)
**Objetivo:** Cachear formato canónico transformado para evitar re-transformación

**Implementación:**
- [x] Creado `CanonicalCache.php` trait (187 líneas, 7d TTL)
- [x] Integrado en HotelbedsHotelProvider + TboHotelProvider (`use CanonicalCache`)
- [x] Modificado transforms: L2 check → transform si miss → L2 store

**Cache keys:** `canonical_hotel_{provider}_{hotel_code}` (7 días TTL)

**Resultados medidos (Cancún: 67 Hotelbeds + 31 TBO = 98 hotels):**

| Métrica | Sin L2 | Con L2 Cache | Mejora |
|---------|--------|--------------|--------|
| **Primera búsqueda (cold - debe poblar L2)** | ~24,233ms | ~24,233ms | 0% (igual) |
| **Segunda búsqueda (L1+L2 warm)** | N/A | **~3,660ms** | **84.9% ↓** vs cold |
| **Content API (Hotelbeds)** | 5,469ms batch | 0ms (100% cached) | L1 SmartCache |
| **Details API (TBO)** | 11,749ms batch | 9.6ms (100% cached) | L1 SmartCache |
| **Transformación** | ~6,000ms (estimado) | **0ms** | **L2 evita transform** |

**Logs confirmados:**
```
[L2-Cache] ⚡ HIT: hotelbeds/370161 ... (67 hotels)
[L2-Cache] ⚡ HIT: tbo/1061037 ... (31 hotels)
[HotelbedsContentBatch] ✨ All 67 hotels served from cache
[TboDetailsBatch] ✨ All 31 hotels served from cache (9.60ms)
[TCM] ✅ UnifiedHotelEndpoint completed: 10 total hotels from 2 providers (3660.21ms)
```

**Conclusión:** 
- ✅ L2 canonical cache **100% efectivo** (98/98 hotels hit)
- ✅ Búsquedas subsiguientes **~7x más rápidas** (24s → 3.6s)
- ✅ Transforma datos provider → formato canónico **solo una vez**, reutiliza 7 días

**Archivos:** 
- `classes/Providers/Traits/CanonicalCache.php` (nuevo)
- `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php` (integrado)
- `classes/Providers/Tbo/TboHotelProvider.php` (integrado)

---

### ⚡ Phase 3.1: CanonicalCache Critical Fixes (**Feb 10, 2026**)
**Objetivo:** Corregir 4 issues críticos identificados en audit sin romper TBO certification feedbacks

**Código protegido (NO TOCAR - TBO Feedbacks #10-#21):**
- ❌ Constantes TBO: `MAX_HOTEL_CODES_PER_REQUEST`, `BOOK_TIMEOUT_SECONDS`, `NAME_MIN/MAX_LENGTH`, `RESPONSE_TIME_*`
- ❌ Métodos de validación: `normalize_tbo_name()`, `validate_tbo_name()`, `compare_cancellation_policies()`, `calculate_response_time()`
- ❌ Timeout recovery logic: `book()` líneas 199-240, `cancel()` líneas 317-389
- ❌ SmartCache pattern TBO: `fetch_hotel_details()` líneas 1038-1150
- ❌ BookingDetail extended signature: `get_booking_detail()` con BookingReferenceId support

**Fixes SEGUROS implementados:**

1. **✅ Fix #1: Data Validation** - Validar `$canonical_hotel` antes de cachear
   - Previene cache poisoning (caches vacíos/null por 7 días)
   - Valida campos mínimos: `hotelCode`, `hotelName`
   - Log warning cuando data es inválida

2. **✅ Fix #2: Schema Versioning** - Versión en cache keys
   - Cache key: `canonical_hotel_{provider}_{code}` → `canonical_hotel_v1_{provider}_{code}`
   - Previene issues en deployment/rollback cuando estructura cambia
   - Constante `CANONICAL_CACHE_VERSION = 1`

3. **✅ Fix #3: DELETE with LIMIT** - Protección contra timeout en clear_cache()
   - Query: `DELETE ... LIMIT 10000` (vs DELETE sin límite)
   - Previene timeout en databases grandes
   - Ejecuta múltiples pasadas si necesario

**Archivos modificados:**
- `classes/Providers/Traits/CanonicalCache.php`

**Impacto TBO:** ✅ **CERO** - Fixes no tocan lógica de negocio TBO, solo capa de cache interna

---

## 🚀 SIGUIENTES PHASES

### ⏳ Phase 4: Parallel Provider Execution
**Objetivo:** Reducir 3,660ms → <2,000ms ejecutando TBO + Hotelbeds en paralelo

**Problema actual:**
- Búsqueda **secuencial**: TBO (1.2s) → espera → Hotelbeds (1.8s) = 3.0s total
- Con overhead: ~3,660ms observado
- Desperdicia tiempo esperando respuestas API

**Solución propuesta:**
- **Ejecución paralela** usando WordPress async requests o PHP forks
- TBO y Hotelbeds ejecutan **simultáneamente**
- Tiempo total = `max(TBO_time, Hotelbeds_time)` vs suma actual

**Tareas:**
- [ ] Investigar opciones: WordPress HTTP API async, ReactPHP, Guzzle Promises
- [ ] Diseñar `ParallelProviderExecutor` class
- [ ] Modificar `UnifiedHotelEndpoint` para ejecutar providers en paralelo
- [ ] Implementar timeout handling (fail gracefully si 1 provider falla)
- [ ] Testing con ambos providers
- [ ] Medir performance (target: <2,000ms)

**Performance esperado:**
```
ANTES (secuencial):
TBO: 1,200ms → espera → Hotelbeds: 1,800ms = 3,000ms + overhead
Total: ~3,660ms

DESPUÉS (paralelo):
TBO: 1,200ms ⎤
                ⎬ → max(1,200, 1,800) = 1,800ms + overhead
Hotelbeds: 1,800ms ⎦
Total esperado: ~2,000ms (45% reducción)
```

---

### ⏳ Phase 4.1: Additional Performance Optimizations

#### 4. Lazy loading frontend
**Objetivo:** Mejorar UX percibida mostrando resultados progresivamente

**Tareas:**
- [ ] Crear endpoint `/tcm/v1/hotel-content/{provider}/{code}` (fetch individual hotel content)
- [ ] Implementar `LazyContentLoader.js` utility con IntersectionObserver
- [ ] Progressive loading strategy:
  - [ ] Fase 1: Títulos + precios (fast)
  - [ ] Fase 2: Imágenes primarias (lazy, visible viewport only)
  - [ ] Fase 3: Galleries + amenities (on-demand)
- [ ] Mobile optimization (skip images on slow connections)
- [ ] Loading skeletons para UX
- [ ] Error handling graceful (fallback to cached data)

**Beneficio:** Usuario ve resultados básicos en ~600ms (vs ~3,500ms actual full load)

---

### ⏳ Phase 4.2: Pre-Caching Popular Destinations
**Objetivo:** Calentar cache proactivamente para destinos frecuentes

**Tareas:**
- [ ] Crear `PreCacheManager` class en `classes/Cache/`
- [ ] Identificar top 10 destinos (analytics o manual seed)
- [ ] WP-Cron job hourly: `wp_schedule_event('hourly', 'tcm_precache_popular_destinations')`
- [ ] Configuración por entorno (production only, skip dev/test)
- [ ] Monitoring de cache hit rates (before/after pre-caching)
- [ ] Admin dashboard para ver pre-cache status
- [ ] Throttling para evitar API rate limits

**Configuración `.env`:**
```
TCM_PRECACHE_ENABLED=true          # Only in production
TCM_PRECACHE_DESTINATIONS=CUN,CDG,NYC,LON  # Top destinations
TCM_PRECACHE_CHECK_IN_OFFSET=7    # Days ahead to cache
```

---

### 📚 DOCUMENTACIÓN

#### 6. Verificación y actualización de documentación
**Objetivo:** Mantener docs sincronizados con código actual

**Tareas:**
- [ ] **Escanear codebase:**
  - [ ] Ignorar: node_modules, vendor, .md, build/
  - [ ] Buscar: @since, @deprecated, TODO comments
  - [ ] Identificar arquitectura changes no documentados
  
- [ ] **Actualizar PROJECT-CONTEXT.md:**
  - [ ] Arquitectura de caching (L1 raw + L2 canonical, SmartCache pattern)
  - [ ] Batch pattern por provider (Hotelbeds Content API, TBO HotelDetails)
  - [ ] Content API integration details (Hotelbeds endpoints, transformations)
  - [ ] Performance benchmarks actualizados (current vs target)
  
- [ ] **Actualizar README.md:**
  - [ ] Command reference actualizado (`run-autoload.sh`, `clear-transients.sh`, etc.)
  - [ ] Environment variables nuevas (TCM_PRECACHE_*, etc.)
  - [ ] Performance metrics section
  - [ ] Troubleshooting común (cache issues, API errors, performance debugging)
  
- [ ] **Crear docs/caching-architecture.md** (nuevo):
  - [ ] Diagrama de flujo L1/L2 cache
  - [ ] SmartCache pattern explanation
  - [ ] Cache key naming conventions
  - [ ] TTL strategy por tipo de dato
  - [ ] Cache invalidation strategies
  
- [ ] **Crear docs/performance-optimization.md** (nuevo):
  - [ ] Batch API patterns
  - [ ] N+1 problem solutions
  - [ ] Lazy loading strategies
  - [ ] Pre-caching best practices
  - [ ] Profiling tools usage

---

## ✅ COMPLETED (Previous Work)

### Sprint 1 - Hotelbeds Content API Integration (Feb 10, 2026)
- ✅ Identificación del problema: Booking API no retorna imágenes
- ✅ Implementación de Content API individual (`get_hotel_content()`)
- ✅ Transformación de imágenes con base URL (`IMAGE_BASE_URL` constant)
- ✅ Transformación de facilities a amenities canónicos
- ✅ Cache individual 30 días por hotel
- ✅ TextNormalizer enhanced para texto concatenado

**Resultado:** Hotelbeds retorna 94 imágenes, descripción 1982 chars, 98 amenities (vs null antes)

---

## 📊 Performance Metrics

### Current State (Feb 11, 2026)

| Provider | First Search | Cached Search | API Calls | Status |
|----------|--------------|---------------|-----------|--------|
| **TBO** | ~1,750ms | ~500ms | 6 (1 search + 5 details batches) | ⚠️ Batch cache suboptimal |
| **Hotelbeds** | ~10,800ms | ~3,900ms | 2 (1 search + 1 content batch) | ✅ Batch implemented, SmartCache active |

### Target State (After Phase 2-3 optimization)

| Provider | First Search | Cached Search | API Calls | Improvement |
|----------|--------------|---------------|-----------|-------------|
| **TBO** | ~800ms | ~400ms | 2 (1 search + 1 details SmartCache batch) | ⚡ 54% faster |
| **Hotelbeds** | ~10,800ms | ~600ms (L2 cache) | 2 (already optimized) | ⚡ 84% faster (cached) |

**Notes:**
- Hotelbeds first search slow incluye Booking API (~5.2s) + Content batch (~5.6s)
- Content batch tiempo es constante (~5.6s para 67 hotels), no escala linealmente
- L2 cache (Phase 3) skip transformat ion → ~600ms cached
- Production API latencies pueden diferir (TEST API usado para desarrollo)

---

## 🔧 Development Workflow

1. **Before starting task:** Mark as ⏳ IN PROGRESS en este archivo
2. **Commit frequently:** Small, focused commits con descriptive messages
3. **Test after each change:** Verify functionality + performance benchmarks
4. **Update metrics:** Document performance impact en esta sección
5. **Mark complete:** Move to ✅ COMPLETADO with date + results summary
6. **Update docs:** Sync changes to PROJECT-CONTEXT.md, README.md

**Testing commands:**
```bash
# Clear cache
docker compose exec wordpress wp transient delete --all --quiet

# Test search (Cancún)
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'

# Check logs
docker logs travel-concierge-me-builder-wordpress-1 --tail 100 | grep -E "\[HotelbedsContent|\[TBO"
```

---

## 📝 Notes

- **Priority order** reflects impact/effort ratio
- **Performance numbers** are for TEST environment (10 hotels/search, 67 total Cancún)
- **Cache TTLs** can be adjusted based on real usage patterns:
  - Content API: 30 days (rarely changes)
  - HotelDetails: 24 hours (prices may fluctuate)
  - Destinations: 24 hours (availability)
- **SmartCache pattern** ya implementado en Hotelbeds, reutilizable para otros providers
