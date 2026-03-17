# TODO-DONE — Travel Concierge Me

Archivo de tareas completadas. Los TODOs se mueven aquí automáticamente al completarse.

---

## ✅ Completado: 2026-02-21

### TODO-01 — Corregir routing en `handle_book()`
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`  
**Cambio:** Añadido paso 5 en `handle_book()`: llamada a `$this->get_provider_for_session($session)` inmediatamente después de validar ownership, antes del check de idempotencia. Reemplazado `$this->booking_provider->book($session)` por `$provider->book($session)`.  
**Resultado:** `handle_book()` ahora sigue el mismo patrón que `handle_prebook()`. Sesiones Hotelbeds son ruteadas correctamente vía `ProviderFactory`.

---

### TODO-00 — Extraer `get_provider_for_session()` a una `ProviderFactory`
**Archivo creado:** `classes/Providers/ProviderFactory.php`  
**Archivos modificados:** `TBO/Endpoint.php`, `UnifiedHotelEndpoint.php`, `Hotelbeds/Endpoint.php`  
**Resultado:** Cero `new TboHotelProvider` ni `new HotelbedsHotelProvider` en endpoints. Classmap actualizado (186 clases).

### TODO-02 — Corregir verificación de idempotencia en `handle_book()`
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`
**Cambio:** Reemplazado `$session["tboBooking"]["bookingId"]` hardcodeado por lógica provider-agnostic:
```php
$provider_name       = $provider->get_provider_name();
$booking_session_key = $provider_name === "hotelbeds" ? "hotelbedsBooking" : "tboBooking";
$existing_booking_id = $session[ $booking_session_key ]["bookingId"] ?? null;
```
**Contrato establecido:** TBO escribe en `tboBooking`, Hotelbeds escribirá en `hotelbedsBooking` (TODO-06).
**Resultado:** Doble-submit protegido para ambos providers.

---

## ✅ Completado: 2026-02-21

### TODO-04 — Implementar `HotelbedsHotelProvider::book()` — Construcción del payload
**Archivo:** `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php`  
**Cambio:** Reemplazado `throw new RuntimeException(...)` con implementación completa del método. Añadido método privado `validate_book_session()` + `build_hotelbeds_book_payload()` en nueva sección `// ==================== BOOK HELPERS ====================`.
- `holder`: `session.guestDetails[0].firstName / lastName`
- `rooms[].rateKey`: `session.rooms[0].bookingCode`
- `rooms[].paxes`: tipo `AD`/`CH` según `age < 18`; `age` incluido en payload para niños
- `clientReference`: `TCM-{sessionId[0..12]}`
- `tolerance`: `2`
**Resultado:** Payload construido y validado. PHP syntax OK.

### TODO-05 — Implementar `HotelbedsHotelProvider::book()` — Llamada API y respuesta canónica
**Archivo:** `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php`  
**Cambio:** Completado en la misma iteración que TODO-04 (inseparable en una sola función). Añadidos métodos privados:
- `transform_hotelbeds_book_to_canonical()`: `booking.reference` → `bookingId`, `booking.clientReference` → `confirmationNumber`, `booking.status`, `booking.totalNet`/`currency` → `totalPrice`
- `build_book_error_response()`: devuelve canonical error `{success:false, provider, error, meta}`
- `build_book_debug_metadata()`: solo activo con `TCM_API_DEBUG_MODE`
**Resultado:** `book()` completamente implementado. Llama a `call_hotelbeds_booking_api('/bookings', $payload, 'POST')`, valida `booking.reference` en respuesta, retorna canónico.

### TODO-03 — Corregir `'provider' => 'tbo'` hardcodeado en respuesta de `handle_book()`
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`  
**Cambio:** `'provider' => 'tbo'` → `'provider' => $provider_name` (ya en scope desde TODO-02).  
**Resultado:** La respuesta de `/bookingBook` reporta el provider correcto para cualquier sesión.  
**Nota:** Las líneas equivalentes en `handle_booking_detail()`, `handle_cancel()` y `handle_booking_details_by_date()` quedan pendientes en TODO-09.

---

## ✅ Completado: 2026-02-21

### TODO-06 — Persistir resultado de book Hotelbeds en la sesión
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`  
**Estrategia elegida:** Claves por-provider (`tboBooking` / `hotelbedsBooking`) — consistente con el contrato establecido en TODO-02. No se usó clave canónica compartida para evitar romper la lectura de idempotencia ya existente.  
**Cambios en `handle_book()` paso 9:**
- Reemplazado bloque hardcodeado `$session['tboBooking'][...]` por escritura usando `$booking_session_key` (ya en scope del paso 6)
- Campos comunes escritos para ambos providers: `bookingStatus`, `bookingId`, `confirmationNo`, `status`, `voucherUrl`, `totalPrice`
- Campos TBO-exclusivos (`bookingRefNo`, `isPriceChanged`) escritos solo cuando `$provider_name === 'tbo'`  
**Cambios en `handle_book()` paso 12 (respuesta):**
- `$book_data['statusCode']` → `$book_data['statusCode'] ?? null` (TBO-only)
- `$book_data['isPriceChanged']` → `$book_data['isPriceChanged'] ?? null` (TBO-only)  
**Resultado:** Sesiones Hotelbeds escriben en `session['hotelbedsBooking']`; la lectura de idempotencia (paso 6) ya usaba `$booking_session_key` → flujo completo coherente.

---

## ✅ Completado: 2026-02-21

### TODO-07 — Manejo de error cuando `book()` lanza excepción
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`  
**Cambio:** Envuelto `$provider->book($session)` en `try/catch(\Exception $e)`. En caso de excepción no capturada:
- Logea `[TBOBooking] ❌ Uncaught exception in {ClassName}::book(): {message}`
- Retorna `WP_Error('book_exception', 'Booking failed: ...', ['status' => 500])`

En lugar del anterior HTTP 500 sin cuerpo que rompía el flujo del frontend.  
**Corrección adicional:** Eliminado comentario duplicado `// 7)` y renumerados los pasos posteriores (8→9→10→11→12→13→14) para que sean secuenciales.  
**Resultado:** Cualquier `RuntimeException` de un provider no implementado (ej. futuro provider) devuelve error amigable en lugar de fatal.

---

## ✅ Completado: 2026-02-21

### TODO-08 — `handle_cancel()` y `handle_booking_detail()` no ruteaban a Hotelbeds
**Archivo:** `classes/Endpoints/TBO/Endpoint.php`  
**Cambio:** Los tres handlers (`handle_booking_detail`, `handle_cancel`, `handle_booking_details_by_date`) reemplazaron el guard `if (!$this->booking_provider)` por resolución vía `ProviderFactory`:
- `handle_booking_detail()` y `handle_cancel()`: leen `$request->get_param('provider') ?: 'tbo'`, llaman `ProviderFactory::make($provider_name)`, devuelven `$provider_name` en respuesta.
- `handle_booking_details_by_date()`: siempre `ProviderFactory::make('tbo')` — endpoint TBO-only.
- Añadido parámetro `provider` (default `'tbo'`) a las rutas `/booking/detail` y `/booking/cancel`.
- Todas las llamadas a provider envueltas en `try/catch`.
- `add_status_event()` en `handle_cancel()` ahora pasa `$provider_name` en lugar de `'tbo'` hardcodeado.  
**Resultado:** Cancel y BookingDetail funcionan para Hotelbeds enviando `provider: "hotelbeds"` en el body.

---

### TODO-09 — Implementar `HotelbedsHotelProvider::cancel()`
**Archivo:** `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php`  
**Cambio:** Reemplazado `throw new RuntimeException(...)` con implementación completa:
- Llama `DELETE /bookings/{bookingId}?cancellationFlag=CANCELLATION` vía `call_hotelbeds_booking_api()`.
- Acepta `bookingId` o `confirmationNumber` como identificador.
- Devuelve canónico `{cancelled, confirmationNumber, bookingId, cancellationReference, status, cancellationCharge}` + `meta.traceId/performanceMs`.
- Errores devueltos como canónico `{success:false, error{code,message,details}}` — sin excepciones no manejadas.  
**Resultado:** PHP syntax OK. Integrado con `handle_cancel()` vía provider param.

---

### TODO-10 — Implementar `HotelbedsHotelProvider::get_booking_detail()`
**Archivo:** `classes/Providers/Hotelbeds/HotelbedsHotelProvider.php`  
**Cambio:** Reemplazado `throw new RuntimeException(...)` con implementación completa:
- Llama `GET /bookings/{bookingId}` vía `call_hotelbeds_booking_api()`.
- Acepta `confirmationNumber` o `bookingReferenceId` como identificador.
- Devuelve canónico `{bookingStatus, confirmationNumber, clientReference, creationDate, hotel_data{...}, guest_details[], rooms[], cancellation_policy, hotel_norms, holder, modificationPolicies}` — compatible con estructura que esperan los BlockRenderers.
- Errores devueltos como canónico `{success:false}` — sin excepciones no manejadas.  
**Resultado:** PHP syntax OK. Integrado con `handle_booking_detail()` vía provider param.

---

### Extras completados en este sprint (sin número de TODO)
- `sanitize_text_field()` corrompía rateKey Hotelbeds → reemplazado con `sanitize_booking_code()` — ver `docs/edge-cases/2026-02-21-sanitize-text-field-corrupts-provider-ratekey.md`
- Logs diagnósticos de investigación (PUNTO-1/4, CACHE-CHECK/HIT/MISS, HotelbedsRAW) eliminados de `HotelbedsHotelProvider.php`
- **Primera reserva Hotelbeds confirmada en TEST API** — `TCM-4B5E47D6-D9B` — status `CONFIRMED` ✅

---

## ✅ Completado: 2026-03-17

### TODO-7 — TBO: cards completamente vacías cuando HotelDetails falla
**Archivo:** `classes/Providers/Tbo/TboHotelProvider.php`  
**Encontrado:** 2026-03-04 mediante simulación con `TCM_SIMULATE_HOTEL_DETAILS_ERROR=1`  
**Resuelto por:** Sprint TBOHotelCodeList Static Content Strategy (16-17 Mar 2026)

**Cambio implementado:** `transform_hotel_to_canonical()` ahora tiene cadena de precedencia completa:
```
search data → code_list static → HotelDetails enrichment → stale L1 cache → fallback ('Hotel {code}')
```

Cuando `/HotelDetails` falla, `hotel_code_list_static` (poblado por `resolve_hotel_codes_for_city()`) provee: `HotelName`, `HotelAddress`, `CountryName`, `CityName`, `Rating`, `HotelFacilities`, `Images`, `Attractions`, y más (16 campos).

**Campo `_contentSource`** trackea la fuente utilizada:
- `'search'` — datos básicos del response /Search
- `'code_list'` — datos estáticos de /TBOHotelCodeList
- `'enrichment'` — datos completos de /HotelDetails
- `'code_list+enrichment'` — combinación de ambas fuentes
- `'stale_l1'` — L1 cache expirado usado como fallback
- `'fallback'` — placeholder 'Hotel {code}' (último recurso)

**Campo `_contentAvailable`:** `true` cuando `$content_source !== 'none'` — permite al frontend saber si hay datos reales.

**Resultado:** Cards nunca aparecen completamente vacías. Phase 6 validado con búsqueda live en Cancún: 10/10 hoteles TBO con nombres reales, todos con `_contentSource: 'code_list'`. Sin cambios en la estructura canónica visible para el frontend.
