# TODO - Travel Concierge Me

> **📝 Nota:** Trabajo completado de Phases 1-4 (Performance Optimization Sprint) movido a [TODO-OLD.md](TODO-OLD.md)

---

## 🎯 SPRINT ACTUAL - Frontend UX Improvements (Feb 11, 2026)

### ⏳ Task 1: Mejorar Filtros de Hoteles
**Problema:** Los filtros actuales no están adaptados a la estructura de resultados multi-provider

**Análisis necesario:**
- [ ] Revisar estructura actual de filtros en frontend
- [ ] Identificar qué filtros existen (`HotelFilters.js` o similar)
- [ ] Verificar compatibilidad con formato canónico actual
- [ ] Analizar campos disponibles en respuesta API:
  - `rating` (0-5 estrellas)
  - `pricePerNight` (rango de precios)
  - `amenities[]` (wifi, pool, spa, etc.)
  - `provider` (hotelbeds, tbo)
  - `city`, `country`

**Tareas de implementación:**
- [ ] **Filtro por precio:**
  - [ ] Range slider (min-max price)
  - [ ] Actualizar en tiempo real sin recargar
  - [ ] Mostrar count de hoteles que cumplen filtro
  
- [ ] **Filtro por rating:**
  - [ ] Checkbox/radio buttons (5★, 4★+, 3★+)
  - [ ] Visual feedback con estrellas
  
- [ ] **Filtro por amenities:**
  - [ ] Checkboxes múltiples (WiFi, Pool, Parking, Spa, Restaurant)
  - [ ] Tooltip con descripción de cada amenity
  - [ ] Counter de hoteles con cada amenity
  
- [ ] **Filtro por provider (opcional):**
  - [ ] Radio buttons: "Todos", "Hotelbeds", "TBO"
  - [ ] Mostrar performance metrics por provider
  
- [ ] **Reset filters:**
  - [ ] Botón "Limpiar filtros"
  - [ ] Guardar estado de filtros en URL (query params)
  - [ ] Restaurar filtros al volver de detalle

**Archivos esperados:**
- `assets/scripts/components/HotelFilters.js`
- `assets/scripts/sections/hotel-results-handler.js`
- `assets/styles/sections/_hotel-filters.scss`

**Criterios de aceptación:**
- ✅ Filtros aplican instantáneamente (sin reload)
- ✅ Combinación de múltiples filtros (AND logic)
- ✅ Counter de resultados actualizado en tiempo real
- ✅ Mobile responsive (collapse filters en <768px)
- ✅ Estado persistente en URL

---

### ⏳ Task 2: Estabilizar Paginación
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
