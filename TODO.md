# TODO - Travel Concierge Me

> **📝 Nota:** Trabajo completado de Phases 1-4 (Performance Optimization Sprint) movido a [TODO-OLD.md](TODO-OLD.md)

---

## 🎯 SPRINT ACTUAL - Frontend UX Improvements (Feb 11, 2026)

### ✅ Task 1: Fix Amenities Filter (COMPLETADO - Feb 11, 2026)

**Contexto Importante:**
- ✅ Los filtros ya están configurados desde **Gutenberg** (no agregar campos nuevos ahora)
- ✅ La **capa canónica** se encargará de adaptar estos filtros a los resultados
- ✅ Los filtros se **populan dinámicamente** con los resultados disponibles
- ✅ Respetar classnames actuales (configuradas desde bloques Gutenberg)
- 🔮 Futuro: permitir agregar filtros con classname específica (no es prioridad ahora)

---

#### 🔍 ANÁLISIS COMPLETADO

**Filtros Implementados en `HotelFiltersManager.js`:**
1. ✅ `name` - Búsqueda por nombre de hotel (texto) - **FUNCIONA**
2. ✅ `rating` - Calificación por estrellas 1-5 (radio/checkbox) - **FUNCIONA**
3. ✅ `address` - Búsqueda por dirección (texto) - **FUNCIONA**
4. ✅ `roomName` - Búsqueda por habitación (texto) - **FUNCIONA**
5. ✅ `mealTypes` - Preferencias de alimentos (AI, RO, BB, HB, FB) - **FUNCIONA**
6. ✅ `cancellationPolicies` - Reembolsable/No reembolsable - **FUNCIONA**
7. ✅ **`amenities` - Amenidades del hotel - FIXED** ✨
8. ✅ `priceRange` - Rango de precio (min/max sliders) - **FUNCIONA**
9. ⚠️ `promotions` - Propiedades destacadas - **VACÍO EN API** (por ahora)

---

#### 🐛 PROBLEMA IDENTIFICADO Y RESUELTO: Amenities Filter

**Root Cause:**
```javascript
// HotelFiltersManager.js línea 214-217 (extractUniqueValues)
if (Array.isArray(hotel.facilities)) {  // ❌ facilities NO EXISTE en API
    hotel.facilities.forEach(facility => {
        if (facility) this.uniqueValues.amenities.add(facility);
    });
}

// línea 538 (applyClientSideFilter)
const hotelAmenities = hotel.facilities || [];  // ❌ facilities = null
```

**Estructura Real de la API Canónica:**
```javascript
// ❌ NO EXISTE:
hotel.facilities = null

// ✅ EXISTE:
hotel.amenities = [
  { code: 30, description: "Wi-fi", voucher: false },
  { code: 50, description: "Swimming pool", ... },
  { code: 80, description: "Restaurant", ... },
  // ...98 amenities total (Hotelbeds)
]
```

**Amenities Encontradas en API (sample):**
- Wi-fi, Car park, 24-hour reception
- Room service, Laundry service, Medical service
- Gym, Spa centre, Sauna, Hot tub, Massage
- Restaurant, Bar, Café, Poolside snack bar
- Outdoor pool, Children's swimming area
- Kids' club, Children playground, Babysitting service
- Golf, Fitness, Beach volleyball, Billiards

---

#### ✅ SOLUCIÓN IMPLEMENTADA

**Fix #1: extractUniqueValues() - líneas 214-217**
```javascript
// ANTES:
if (Array.isArray(hotel.facilities)) {
    hotel.facilities.forEach(facility => {
        if (facility) this.uniqueValues.amenities.add(facility);
    });
}

// DESPUÉS:
if (Array.isArray(hotel.amenities)) {
    hotel.amenities.forEach(amenity => {
        if (amenity?.description) {
            this.uniqueValues.amenities.add(amenity.description);
        }
    });
}
```

**Fix #2: applyClientSideFilter() - líneas 538-542**
```javascript
// ANTES:
if (this.activeFilters.amenities.size > 0) {
    const hotelAmenities = hotel.facilities || [];
    const hasAmenity = Array.from(this.activeFilters.amenities).some(amenity =>
        hotelAmenities.includes(amenity)
    );
    // ...
}

// DESPUÉS:
if (this.activeFilters.amenities.size > 0) {
    const hotelAmenities = (hotel.amenities || []).map(a => a.description);
    const hasAmenity = Array.from(this.activeFilters.amenities).some(amenity =>
        hotelAmenities.includes(amenity)
    );
    // ...
}
```

---

#### ✅ COMPLETADO

- ✅ **Modificar `extractUniqueValues()` (líneas ~214-217)**
  - Cambiar `hotel.facilities` → `hotel.amenities`
  - Extraer `amenity.description` en vez de usar el objeto completo

- ✅ **Modificar `applyClientSideFilter()` (líneas ~538-542)**
  - Cambiar `hotel.facilities` → `hotel.amenities`
  - Mapear amenities a descriptions antes de comparar

- ✅ **Rebuild Assets:**
  - `npm run build` ejecutado (2.28s)
  - Build exitoso sin errores

- ✅ **Git Commit:**
  - Commit: `fix(filters): cambiar hotel.facilities a hotel.amenities - formato canonico`
  - Branch: `hotelbeds-integration-sprint-2`
  - Files: `HotelFiltersManager.js` (1 file, 7 insertions, 5 deletions)

**Pendiente Testing Manual:**
- [ ] Buscar hoteles en Cancún
- [ ] Verificar que el filtro de amenities se llene con opciones (Wi-fi, Pool, Gym, etc.)
- [ ] Seleccionar "Swimming pool" → verificar que filtra correctamente
- [ ] Combinar con otros filtros (rating + amenities + price)
- [ ] Verificar que muestra contador de hoteles correctamente

---

#### 🎯 Criterios de Aceptación

- ✅ Filtro de amenities se puebla con descripciones reales de la API
- ✅ Código compatible con formato canónico (usa `hotel.amenities`)
- ✅ Extracción correcta de `amenity.description`
- ✅ Filtrado funcional (OR logic dentro de amenities)
- ✅ Compatible con ambos providers (Hotelbeds + TBO)
- ⏳ Testing manual pendiente (recomendado antes de producción)

---

### ⏳ Task 2: Estabilizar Paginación (NO INICIADO)
**Problema:** Al cambiar de página, la paginación "salta" visualmente:
1. Desaparece completamente
2. Reaparece con menos páginas temporalmente
3. Finalmente muestra el número correcto

**Debugging necesario:**
- [ ] Identificar archivo JS de paginación
- [ ] Reproducir issue en dev environment
- [ ] Detectar cuándo se dispara re-render múltiple
- [ ] Verificar si es problema de:
  - Múltiples llamadas API
  - State management inconsistente
  - DOM manipulation timing
  - Filtros aplicándose antes de paginación

**Root causes probables:**

**Hipótesis #1: Race condition en filtros + paginación**
```javascript
// MAL: Filtros y paginación actualizan count simultáneamente
filterChange() {
  this.updateHotels(); // Trigger 1
  this.updatePagination(); // Usa count desactualizado
}

pageChange() {
  this.updateHotels(); // Trigger 2
  this.updatePagination(); // Doble render
}
```

**Solución:**
- [ ] Usar debounce en filtros (300ms)
- [ ] Single source of truth para hotel count
- [ ] Actualizar paginación SOLO después de hotels render completo

**Hipótesis #2: Paginación se recalcula antes de aplicar filtros**
```javascript
// MAL: Order of operations
1. User clicks page 2
2. Pagination updates (shows all pages for unfiltered results)
3. Filters apply
4. Pagination recalculates (now fewer hotels = fewer pages)
5. Visual jump
```

**Solución:**
- [ ] Aplicar filtros ANTES de renderizar paginación
- [ ] Usar loading skeleton durante transición
- [ ] Guardar estado previo y hacer fade transition

**Tareas de implementación:**
- [ ] **Identificar código actual:**
  - [ ] Buscar `pagination` en `assets/scripts/`
  - [ ] Revisar event handlers de page change
  - [ ] Mapear flujo de datos (filter → hotels → pagination)
  
- [ ] **Implementar loading states:**
  - [ ] Skeleton loader para pagination durante carga
  - [ ] Disable clicks durante transición
  - [ ] Smooth opacity transition (evitar "flash")
  
- [ ] **Optimizar re-renders:**
  - [ ] Calcular totalPages UNA VEZ por cambio
  - [ ] Evitar múltiples DOM manipulations
  - [ ] Usar `requestAnimationFrame` para batch updates
  
- [ ] **Mejorar UX:**
  - [ ] Scroll to top al cambiar página (smooth scroll)
  - [ ] Mantener scroll position en filtros (no saltar)
  - [ ] Indicador visual de página actual más prominente
  - [ ] Números de página accesibles (keyboard navigation)

**Archivos esperados:**
- `assets/scripts/components/Pagination.js` (o similar)
- `assets/scripts/sections/hotel-results-handler.js`
- `assets/styles/components/_pagination.scss`

**Criterios de aceptación:**
- ✅ Sin "flash" o desaparición de paginación
- ✅ Transición suave entre páginas (<100ms perceived lag)
- ✅ Count de páginas correcto DESDE el primer render
- ✅ No se ejecutan múltiples API calls por page change
- ✅ Accessible (keyboard nav, ARIA labels)
- ✅ Mobile responsive (simplified pagination en mobile)

---

## 📋 Checklist General

### Antes de empezar
- [ ] Reproducir ambos issues en dev environment
- [ ] Tomar screenshots/video del comportamiento actual
- [ ] Identificar archivos JS/SCSS involucrados
- [ ] Revisar formato de datos API response (`/tcm/v1/hotels-search`)
- [ ] Verificar browser console para errores JS

### Durante desarrollo
- [ ] Commits frecuentes con mensajes descriptivos
- [ ] Testing en Chrome, Firefox, Safari
- [ ] Testing en mobile (responsive breakpoints)
- [ ] Logging para debugging (usar `console.group()`)
- [ ] Performance profiling (Chrome DevTools)

### Antes de marcar completo
- [ ] Code review en GitHub (crear PR)
- [ ] Testing manual de casos edge:
  - Filtros sin resultados (mostrar mensaje)
  - Página inexistente (redirect a última válida)
  - API error (fallback graceful)
- [ ] Actualizar comentarios de código
- [ ] Remover `console.log()` de debugging
- [ ] Verificar bundle size (no inflar JS innecesariamente)

---

## 🔧 Development Commands

```bash
# Build frontend assets (watch mode)
cd themes/travel-concierge-me-theme/assets
npm run dev

# Build production
npm run build

# Check for JS errors
npm run lint

# Test hotel search endpoint
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'

# Check response format (filters data)
curl ... | jq '.data.hotels[] | {hotelName, rating, pricePerNight, amenities, provider}'

# Browser console debugging
# Add to hotel-results-handler.js:
console.group('[Filters Debug]');
console.log('Active filters:', this.activeFilters);
console.log('Filtered hotels count:', filteredHotels.length);
console.log('Total pages:', Math.ceil(filteredHotels.length / perPage));
console.groupEnd();
```

---

## 📊 Current State (Feb 11, 2026)

**Performance (después de Phase 4):**
- ✅ Cold search: ~24,233ms (primera vez, popula cache)
- ✅ Warm search: ~2,535ms (89.5% más rápido)
- ✅ Execution mode: `parallel` (TBO + Hotelbeds simultáneo)
- ✅ Cache: L1 (raw) + L2 (canonical) activo

**Pendientes frontend:**
- ⏳ Filtros adaptados a multi-provider format
- ⏳ Paginación estable (sin visual jumps)
- 📋 Lazy loading images (future)
- 📋 Pre-caching destinos populares (future)

---

## 📝 Notas

- **Prioridad:** Resolver estabilidad de paginación primero (más crítico para UX)
- **Testing:** Usar dataset Cancún (98 hotels total, 10 por página = 10 páginas)
- **Browser support:** Chrome 90+, Firefox 88+, Safari 14+ (ES6 modules)
- **Accessibility:** WCAG 2.1 Level AA mínimo (keyboard nav, ARIA labels)

---

## 🔗 Referencias

- **API Response Format:** Ver `docs/endpoints-architecture.md`
- **BEM Conventions:** Ver `docs/bem-conventions.md`
- **Frontend Architecture:** Ver `docs/block-renderers-architecture.md`
- **Completed Work:** Ver [TODO-OLD.md](TODO-OLD.md) para Phases 1-4
