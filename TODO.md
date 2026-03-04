# TODO — Travel Concierge Me

Sprint activo: **Hotelbeds Book Integration**  
Fecha de creación: 2026-02-21  
Branch tema: `hotelbeds-integration-sprint-2`

---

## 🟡 MEDIO — Robustez y mantenibilidad

### TODO-1 — Selector de botón "Crear reserva/Reservar" frágil en JS
**Archivo:** `assets/scripts/modules/bookingButtonHandler.js`  
**Problema:** El botón se localiza buscando texto que contenga "crear reserva", "voucher" o "emitir". Si el texto cambia en Gutenberg, el listener no se adjunta y el flujo de reserva queda silenciosamente roto. Afecta también al botón "Reservar" de la página de hoteles.  
**Solución conceptual:** Agregar `data-action="create-booking"` / `data-action="reserve-hotel"` como CSS class o HTML Anchor en el Advanced panel de Gutenberg (visible en capturas), y buscar por ese atributo desde JS en lugar de texto.  
**Nota:** Pendiente para el final del sprint — hay múltiples botones afectados y requiere coordinación con el editor Gutenberg.

### TODO-2 — Base de datos interna de bookings canónicos para enriquecer consultar-reserva
**Archivos afectados:**
- `classes/Database/BookingsTable.php` (nuevo)
- `classes/Database/DatabaseManager.php` (registrar nueva tabla)
- `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php` (`book()` method)
- `classes/Providers/Tbo/TboHotelProvider.php` (`book()` method)
- `classes/Endpoints/TBO/Endpoint.php` (`handle_booking_detail()` method)

**Problema:**  
Hotelbeds Booking Detail API no devuelve `email`/`phone` de huéspedes (solo `name`/`surname`), a diferencia de TBO que sí los incluye en `Guest.Email`/`Guest.PhoneNo`. Esto causa que en la página **consultar-reserva**, las reservas de Hotelbeds muestren huéspedes sin datos de contacto.

**Causa raíz:**  
Es una limitación del API de Hotelbeds — `ApiHolder` y `paxes` en el booking detail response solo devuelven nombres ([OpenAPI-Hotel-BookingAPI-3.0.yaml L5206-5228](docs/hotelbeds-api/OpenAPI-Hotel-BookingAPI-3.0.yaml#L5206-L5228)). El campo `contactData` (email/phone) solo existe en el **request** de booking (para pago con tarjeta), no en la respuesta.

**Impacto:**  
- ✅ TBO: Muestra email/phone en consultar-reserva
- ❌ Hotelbeds: Solo muestra nombres (email/phone = `null`)
- ⚠️ Inconsistencia en UX multi-provider

**Solución conceptual:**  
1. **Crear tabla `tcm_bookings`** con schema canónico:
   ```sql
   CREATE TABLE tcm_bookings (
     id BIGINT AUTO_INCREMENT PRIMARY KEY,
     booking_id VARCHAR(50) NOT NULL UNIQUE,
     confirmation_number VARCHAR(50) NOT NULL,
     provider VARCHAR(20) NOT NULL,
     status VARCHAR(20) NOT NULL,
     guest_details JSON NOT NULL,  -- Array completo con email/phone
     hotel_data JSON NOT NULL,
     search_params JSON NOT NULL,
     rooms JSON NOT NULL,
     total_amount DECIMAL(10,2),
     currency VARCHAR(3),
     created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
     INDEX idx_confirmation (confirmation_number),
     INDEX idx_provider (provider),
     INDEX idx_status (status)
   )
   ```

2. **Modificar `book()` en ambos providers** para insertar en DB después de booking exitoso:
   ```php
   // Después de transform_hotelbeds_book_to_canonical() / TBO equivalent
   $this->store_booking_in_database($canonical_response, $session);
   ```

3. **Modificar `handle_booking_detail()`** en TBO/Endpoint.php:
   - Primero intentar leer de `tcm_bookings` (datos completos)
   - Si no existe o falla, fallback a provider API (datos limitados)
   - Merge ambos: usar DB para `guestDetails`, API para status actual

**Beneficios adicionales:**
- ✅ Backup local de todas las reservas (auditoría)
- ✅ Consultas rápidas sin depender de APIs externas
- ✅ Base para futuras features (reportes, analytics, notificaciones)
- ✅ Permite enriquecer datos de cualquier provider con limitaciones

**Testing:**  
1. Crear booking con Hotelbeds (email/phone enviados en session)
2. Verificar inserción en `tcm_bookings` con `guestDetails` completo
3. Consultar reserva en `/consultar-reserva` → debe mostrar email/phone
4. Verificar que TBO sigue funcionando igual (DB como backup)

**Dependencias:** Ninguna (puede ejecutarse en paralelo o después de TODO-1)

---

## 🟢 BAJO — Mantenibilidad técnica (cache)

### TODO-3 — Cap booking session payload size
**Archivos afectados:**
- `classes/Endpoints/BookingSession/Endpoint.php` (`handle_create_session()`)
- `classes/Endpoints/TBO/Endpoint.php` (`save_booking_session()`)

**Problema:** El transient `tcm:session:booking:{uuid}` crece sin límite a lo largo del flujo Search → PreBook → Book. Puede alcanzar 200+ KB. El endpoint de TBO tiene un threshold de advertencia de 1 MB pero no hay un cap activo.

**Solución conceptual:**
1. Identificar qué secciones del payload son imprescindibles por fase vs. acumuladas innecesariamente
2. En `save_booking_session()`: antes de `set_transient`, serializar y validar tamaño: `if ( strlen( serialize( $session ) ) > 500_000 ) { error_log(...) }`
3. Evaluar si `tboBooking.priceHistory`, `rooms[].rateConditions` completos son necesarios en sesión o pueden moverse a la DB canónica (ver TODO-2)
4. Agregar hard cap con `wp_json_encode` size check y fallback a almacenamiento parcial

**Nota:** Revisar TODO-2 antes de implementar — una DB canónica de bookings puede resolver este problema estructuralmente.

### TODO-4 — Reemplazar md5 en cache key de TBO API cache
**Archivo afectado:** `classes/Providers/Tbo/Traits/TboApiClient.php`

**Problema:** La clave `tcm:api_cache:tbo:{md5(endpoint+payload+method)}` usa un hash opaco. Es imposible identificar desde `wp_options` (o via WP-CLI) qué endpoint o payload corresponde a cada entrada cacheada, dificultando el debugging.

**Callers actuales con `cache_ttl > 0`:**
- `HotelCodeList` → cache 1800s
- `CountryList` → cache 86400s
- `CountryMap` (o similar) → cache 86400s

**Solución conceptual:**
1. Para los callers conocidos con TTL > 0, construir claves legibles en lugar de md5:
   - `tcm:api_cache:tbo:hotel_code_list:{city_code}` (ya existe en `CacheTtl` como `hotel_code_list`)
   - `tcm:api_cache:tbo:country_list` (ref data, single key)
2. Mantener `md5` como fallback solo para callers desconocidos / dinámicos
3. Verificar que ninguna clave supera los 172 chars (límite WordPress)

---

## � QA / Verificación manual

### TODO-5 — Auditar que todas las notificaciones de usuario estén en español
**Archivos a revisar:**
- `assets/scripts/store/slices/hotelSearchSlice.js` (mensajes de error del thunk `searchHotels`)
- `assets/scripts/classes/HotelSearchManager.js` (mensajes de consola y toast en `performHotelSearch`)
- `assets/scripts/modules/notifications.js` (textos hardcoded si los hay)
- `assets/scripts/modules/hotelCardBooking.js` (`showToast(...)` calls)
- `assets/scripts/classes/URLSearchParamsManager.js` (`showToast(...)` calls)
- `assets/scripts/store/api/errorHandlers.js` (mensajes de `normalizeError`)

**Qué revisar:**
1. Buscar todos los `showToast(`, `setError(`, `showNotification(` y `throw new Error(` con texto en inglés
2. Verificar también mensajes de `logger.error` que lleguen visibles al usuario final
3. Especial atención a: `'Error searching hotels'`, `'Invalid search payload'`, `'Request timeout - please try again'`, `'No previous search to paginate'`

**Criterio de aceptación:** Todo string que el usuario final puede ver debe estar en español. Strings de consola/debug pueden quedarse en inglés.

**Herramienta de búsqueda:**
```bash
grep -rn "throw new Error\|showToast\|setError\|showNotification" \
  themes/travel-concierge-me-theme/assets/scripts/ \
  --include="*.js" | grep -v "node_modules\|dist\|\.min\." | grep -v "//.*Error"
```

---

### TODO-6 — Verificación visual: simular fallos de proveedor y observar el toast en el navegador
**Contexto:** El toast de error parcial fue implementado (2026-03-03) en `hotelSearchSlice.js`. Debe verificarse visualmente en el navegador que el mensaje aparece, se ve bien y el texto es el correcto.

**Pasos para reproducir:**

1. **Activar simulación TBO:**
   ```bash
   # Editar .env
   TCM_SIMULATE_PROVIDER_ERRORS=tbo
   docker compose up -d
   ```

2. **Abrir la página de hoteles con una búsqueda válida:**
   ```
   http://localhost:5050/hoteles/?search=1&geonameId=3531673&country=MX&checkin=2026-07-20&checkout=2026-07-22&nationality=MX&paxrooms=[{"adults":2}]
   ```

3. **Observar:**
   - ✅ Aparece toast tipo `warning` (amarillo/naranja)
   - ✅ Texto: `"Resultados parciales: TBO Holidays no respondió en este momento. Las opciones mostradas pueden no ser exhaustivas."`
   - ✅ El toast tiene botón de cierre (×)
   - ✅ Los resultados de Hotelbeds SÍ se muestran debajo del toast
   - ✅ El toast desaparece solo en ~8 segundos

4. **Repetir con Hotelbeds:**
   ```bash
   TCM_SIMULATE_PROVIDER_ERRORS=hotelbeds
   docker compose up -d
   ```
   - ✅ Toast: `"Resultados parciales: Hotelbeds no respondió..."`
   - ✅ Resultados de TBO se muestran

5. **Restaurar modo normal:**
   ```bash
   TCM_SIMULATE_PROVIDER_ERRORS=none
   docker compose up -d
   ```
   - ✅ Sin toast, ambos providers muestran resultados

**Criterio de aceptación:** El tester confirma visualmente los 3 escenarios (TBO falla, HB falla, ambos OK).

---

## � ALTO — Bugs de resiliencia

### TODO-7 — TBO: cards completamente vacías cuando HotelDetails falla
**Encontrado:** 2026-03-04 mediante simulación con `TCM_SIMULATE_HOTEL_DETAILS_ERROR=1`  
**Archivos afectados:**
- `classes/Providers/Tbo/TboHotelProvider.php` (método `enrich_with_hotel_details` + `transform_hotel_to_canonical`)

**Descripción del bug:**
Cuando `/HotelDetails` de TBO falla (timeout, error de API, o nulo), el método `enrich_with_hotel_details()` retorna `$tbo_response` sin el campo `HotelDetails` en cada hotel. Al transformar a formato canónico, el resultado son hoteles con **todos los campos de enriquecimiento vacíos**:

```
TBO Hotel (sin HotelDetails):
  hotelName:   ❌ vacío   ← el nombre no llega del Search response
  imageUrl:    ❌ vacío
  description: ❌ vacío
  amenities:   ❌ vacío
```

**Comparación:**
```
Hotelbeds (normal):        TBO (HotelDetails OK):     TBO (HotelDetails FAIL):
  hotelName: ✅             hotelName: ✅               hotelName: ❌ VACÍO
  imageUrl:  ✅             imageUrl:  ✅               imageUrl:  ❌ VACÍO
  desc:      ✅             desc:      ✅               desc:      ❌ VACÍO
```

**Impacto en UX:** Los hoteles TBO aparecen como cards en blanco (sin nombre, sin imagen, sin descripción). Es **peor que no mostrarlos**: confunden al usuario y degradan la experiencia.

**Causa raíz:**
`transform_hotel_to_canonical()` para TBO obtiene `hotelName`, `imageUrl`, `description`, `amenities` del campo `HotelDetails` (enriquecimiento). Si ese campo es `null` o ausente, no hay fallback al `HotelName` que SÍ viene en la respuesta del `/Search` de TBO.

**Opciones de solución (en orden de preferencia):**

1. **Filtrar hotels sin nombre** — en `transform_to_canonical()` o `enrich_with_hotel_details()`, excluir hoteles cuyo canonical resultante tiene `hotelName` vacío:
   ```php
   $canonical_hotels = array_filter($canonical_hotels, fn($h) => !empty($h['hotelName']));
   ```

2. **Fallback a datos del Search** — en `transform_hotel_to_canonical()`, usar `$hotel['HotelName']` (del Search) como fallback si `$hotel['HotelDetails']['HotelName']` está vacío.

3. **Marcar como degradado** — retornar los hoteles con un flag `_degraded: true` y que el frontend los omita o los muestre diferenciados.

**La opción 1 es la más segura**: un hotel sin nombre no tiene valor para el usuario.

**Testing:**
```bash
# Activar simulación
TCM_SIMULATE_HOTEL_DETAILS_ERROR=1
docker compose up -d

# Limpiar L2 canonical TBO
docker compose exec wordpress wp --allow-root eval 'global $wpdb; $wpdb->query("DELETE FROM {$wpdb->options} WHERE option_name REGEXP \"_transient_tcm:canonical:v[0-9]+:tbo:\"");'

# Buscar con perPage alto para ver TBO hotels
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-07-20", "checkOut": "2026-07-22", "nationality": "MX", "paxRooms": [{"adults": 2}], "perPage": 100}'

# Verificar: hoteles TBO deben filtrarse (0 TBO en respuesta) o tener hotelName desde Search
```

**Restaurar:**
```bash
TCM_SIMULATE_HOTEL_DETAILS_ERROR=0
docker compose up -d
```

---

## �📋 ORDEN DE EJECUCIÓN

```
TODO-1 (botón frágil JS)

TODO-5 (auditar textos español) → TODO-6 (verificación visual toast)

TODO-7 (TBO cards vacías sin HotelDetails) ← BUG ENCONTRADO 2026-03-04

TODO-3 (session cap) → TODO-2 (DB canónica bookings)

TODO-4 (md5 → readable key TBO)
```
