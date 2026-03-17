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

## 🟡 MEDIO — Optimización de memoria (TBO)

### TODO-8 — Acotar almacenamiento estático en `resolve_hotel_codes_for_city()` (TboHotelProvider)
**Archivo:** `classes/Providers/Tbo/TboHotelProvider.php`  
**Problema:** `resolve_hotel_codes_for_city()` guarda campos estáticos en `$this->hotel_code_list_static` para **todos** los hoteles devueltos por `/TBOHotelCodeList` (potencialmente 1000+ en ciudades grandes), pero la búsqueda posterior solo usa un subconjunto limitado (por defecto `$max_codes = 50`). Con `IsDetailedResponse: true`, cada entrada contiene 16 campos estáticos por hotel — lo que puede inflar innecesariamente la memoria PHP y el tiempo de procesamiento por request.

**Causa raíz:**
```php
// Actualmente: itera TODOS los hoteles de la respuesta completa de /TBOHotelCodeList
foreach ($code_list_response['Hotels'] ?? [] as $hotel) {
    $code = $hotel['HotelCode'] ?? '';
    if ($code) {
        $this->hotel_code_list_static[$code] = [...]; // 16 fields almacenados para TODOS
    }
}
// Pero $codes (los que realmente se usan) tiene máx. MAX_HOTEL_CODES_PER_REQUEST = 100 entradas
```

**Impacto estimado:**
- Ciudad pequeña (~50 hoteles): sin impacto relevante
- Ciudad mediana (~300 hoteles): ~300 entradas almacenadas vs 50-100 usadas
- Ciudad grande (1000+ hoteles): ~1000+ entradas, memoria inflada, procesamiento innecesario

**Solución conceptual:**
Acotar la extracción a los códigos que realmente participan en la request:
```php
// Opción A (preferida): solo almacenar hoteles que están en $codes
if ($code && in_array($code, $codes, true)) {
    $this->hotel_code_list_static[$code] = [...];
}

// Opción B: almacenar hasta MAX_HOTEL_CODES_PER_REQUEST como buffer
if ($code && count($this->hotel_code_list_static) < self::MAX_HOTEL_CODES_PER_REQUEST) {
    $this->hotel_code_list_static[$code] = [...];
}
```

**Restricción crítica — NO romper certificación TBO:**
- `MAX_HOTEL_CODES_PER_REQUEST = 100` es constante de certificación (Feedback #4) — no modificar
- La estrategia de fallback estático DEBE seguir funcionando: si HotelDetails falla para un código, `hotel_code_list_static[$code]` debe estar disponible
- Por eso la **Opción A es preferible**: solo nos interesan los códigos que participan en el search

**Testing:**
```bash
# Buscar en ciudad grande (Madrid ~400 hoteles TBO)
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3117735, "checkIn": "2026-07-20", "checkOut": "2026-07-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'

# Verificar que hoteles TBO mantienen _contentSource: 'code_list' cuando HotelDetails falla
# Añadir error_log temporal: error_log('[TBO] hotel_code_list_static count: ' . count($this->hotel_code_list_static));
# Resultado esperado: count ≤ count($codes)
```

**Dependencias:** Ninguna. Puede ejecutarse en cualquier momento sin afectar otros TODOs.

---

## 📋 ORDEN DE EJECUCIÓN POSIBLE

```
TODO-1 (botón frágil JS)

TODO-5 (auditar textos español) → TODO-6 (verificación visual toast)

TODO-3 (session cap) → TODO-2 (DB canónica bookings)

TODO-4 (md5 → readable key TBO)

TODO-8 (acotar hotel_code_list_static en resolve_hotel_codes_for_city)
```
