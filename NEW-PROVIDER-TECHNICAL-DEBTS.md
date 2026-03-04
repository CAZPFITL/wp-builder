# New Provider Technical Debts

> **Propósito:** Deuda técnica identificada en la arquitectura multi-provider que debería resolverse para mejorar la extensibilidad al agregar nuevos providers.
>
> **Origen:** Auditoría del 2026-02-22"
> **Estado:** Documentado — sin implementar
>
> **Cómo usar este documento:** Antes de agregar un 3er provider, revisar cada item y decidir si se resuelve ahora o se posterga.

---

## 🔴 SEVERIDAD ALTA

Hallazgos que causan confusión, nombres incorrectos, o riesgo de bugs futuros. **Ninguno es bloqueante** para un 3er provider (ver sección "Análisis de bloqueos" al final), pero sí son deuda técnica que acumula fragilidad.

---

### H1 — Session key binario (ternario hardcoded)

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 1376  
**Código actual:**
```php
$booking_session_key = $provider_name === 'hotelbeds' ? 'hotelbedsBooking' : 'tboBooking';
```

**Problema:** Un 3er provider (ej: `'expedia'`) caería en el branch `else`, usando `'tboBooking'` como session key. **Funcionalmente no rompe nada** (el dato se guarda y lee del mismo key), pero el nombre es incorrecto y puede confundir en debugging.

**Fix propuesto:**
```php
$booking_session_key = $provider_name . 'Booking';
// Resultado: 'expediaBooking', 'tboBooking', 'hotelbedsBooking'
```

**Impacto del fix:** Bajo. Requiere verificar que no haya código que lea `$session['tboBooking']` hardcoded fuera de guards `if ($provider_name === 'tbo')`.

---

### H2 — Session init hardcodea `tboBooking`

**Archivo:** `classes/Endpoints/BookingSession/Endpoint.php` línea 275  
**Código actual:**
```php
// Provider booking data
'tboBooking' => [],
```

**Problema:** Al crear una sesión de booking, siempre se inicializa `tboBooking` como key, independientemente del provider. Para un 3er provider, la data termina en esta key genérica (via H1).

**Fix propuesto (opción A — dinámico):**
```php
// Determinar key basado en provider de searchParams
$provider = $search_params['provider'] ?? 'tbo';
$booking_key = $provider . 'Booking';
// ...
$booking_key => [],
```

**Fix propuesto (opción B — key genérica):**
```php
// Reemplazar 'tboBooking' con key agnóstica
'providerBooking' => [],
```

**Nota:** Opción B requeriría migrar TODAS las referencias a `tboBooking`/`hotelbedsBooking` en el codebase (~30 referencias).

---

### H3 — UnifiedHotelEndpoint init() con if/else explícito

**Archivo:** `classes/Endpoints/UnifiedHotelEndpoint.php` líneas 70-76  
**Código actual:**
```php
if (in_array('tbo', $this->active_providers, true)) {
    $this->init_tbo_provider();
}
if (in_array('hotelbeds', $this->active_providers, true)) {
    $this->init_hotelbeds_provider();
}
```

**Problema:** Cada provider nuevo requiere agregar un bloque `if` y un método `init_{name}_provider()`. No es dinámico.

**Fix propuesto:**
```php
foreach ($this->active_providers as $provider_name) {
    $provider = ProviderFactory::make($provider_name);
    if (!is_wp_error($provider)) {
        $this->providers[$provider_name] = $provider;
    }
}
```

**Impacto del fix:** Elimina los métodos `init_tbo_provider()` e `init_hotelbeds_provider()` (~12 líneas). Garantiza que cualquier provider en `TCM_ACTIVE_PROVIDERS` se inicialice automáticamente.

---

### H4 — ProviderFactory usa switch/case estático

**Archivo:** `classes/Providers/ProviderFactory.php` línea 41  
**Código actual:**
```php
switch ($provider_name) {
    case 'tbo':
        return self::make_tbo();
    case 'hotelbeds':
        return self::make_hotelbeds();
    default:
        return new WP_Error(...);
}
```

**Problema:** Requiere agregar manualmente un `case` por provider. Ya está documentado en el PHPDoc del archivo, pero no es un registry dinámico.

**Nota:** Este patrón es **aceptable** y está bien documentado. Un registry dinámico agregaría complejidad innecesaria para 3-5 providers. Se incluye aquí por completitud.

**Prioridad:** BAJA — no requiere fix a menos que se superen 5 providers.

---

### H5 — Método fantasma `persist_booking_to_database()`

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 1455  
**Código actual:**
```php
if (defined('USE_DATABASE') && USE_DATABASE === true) {
    $db_result = $this->persist_booking_to_database($session, $book_data);
}
```

**Problema:** El método `persist_booking_to_database()` **NO EXISTE** en ningún archivo del codebase. Si `USE_DATABASE` se activa, causaría un **PHP Fatal Error** (Call to undefined method).

**Fix propuesto:** Implementar el método o eliminar el bloque. Independiente del multi-provider — es un bug existente.

**Prioridad:** MEDIA — no afecta operación actual (USE_DATABASE no está definido), pero es un riesgo latente.

---

### H6 — No existe HotelbedsBookingAdapter

**Archivo:** `classes/Database/Bookings/Adapters/`  
**Estado actual:** Solo existe `TboBookingAdapter.php`

**Problema:** Si se activa persistencia a DB para Hotelbeds (o un 3er provider), no hay adapter que transforme la data canónica al schema de la tabla `tcm_bookings`.

**Fix propuesto:** Crear `GenericBookingAdapter` o un adapter por provider. Bloqueado por H5 (el método que lo usaría no existe).

**Prioridad:** BAJA — depende de que se implemente la feature de DB persistence.

---

## 🟡 SEVERIDAD MEDIA

Hallazgos que funcionan correctamente pero podrían causar inconsistencias o confusión.

---

### M1 — TBO-specific prebook logic sin hook para otros providers

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 1106  
**Código actual:**
```php
if ($provider_name === 'tbo') {
    $this->handle_tbo_prebook_logic($session, $prebook_data, $canonical_response, $session_id);
}
```

**Problema:** Si un 3er provider necesita lógica custom de prebook (ej: comparación de precios), no hay mecanismo para agregarla sin otro `if`.

**Fix futuro:** Un sistema de hooks/capabilities donde cada provider declara qué post-processing necesita.

---

### M2 — TBO-specific fields en prebook response

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 1150  
**Código actual:**
```php
if ($provider_name === 'tbo') {
    $response_data['data']['priceChanged'] = $price_changed;
}
```

**Problema:** Si otro provider también detecta cambios de precio, necesitaría su propio `if` block. `priceChanged` debería ser un campo canónico.

---

### M3 — TBO-specific session fields en book

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 1441  
**Código actual:**
```php
if ($provider_name === 'tbo') {
    $session[$booking_session_key]['bookingRefNo'] = $book_data['bookingRefNo'] ?? null;
    $session[$booking_session_key]['isPriceChanged'] = $book_data['isPriceChanged'] ?? false;
}
```

**Problema:** Guard correcto (solo TBO tiene estos campos), pero el pattern se repetirá con cada provider que tenga campos únicos. No es mantenible a escala.

---

### M4 — DB migration default `'tbo'`

**Archivos:**
- `classes/Database/Bookings/Migration.php:39`
- `classes/Database/BookingRefs/Migration.php:40`
- `classes/Database/BookingStatusEvents/Migration.php:51`

**Código actual:**
```sql
provider VARCHAR(50) NOT NULL DEFAULT 'tbo'
```

**Problema:** Si un INSERT no especifica `provider`, queda como `'tbo'` silenciosamente. No es un bug si los adapters siempre envían el valor, pero es un safety concern.

**Fix propuesto:** Cambiar a `NOT NULL` sin default (forzar explicit value), o cambiar default a `''` (string vacío) para detectar omisiones.

---

### M5 — `/booking/details-by-date` hardcoded a TBO

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` ~línea 1770  
**Código actual:**
```php
$provider = ProviderFactory::make('tbo');
```

**Problema:** Este endpoint siempre consulta TBO, independientemente del provider param. Es **intencional** (solo TBO soporta `get_booking_details_by_date_range()`) pero no está documentado ni validado.

**Fix futuro:** Agregar `get_booking_details_by_date_range()` al interface, o mover a un endpoint TBO-only.

---

### M6 — Admin.php tiene registro explícito de endpoints

**Archivo:** `classes/Admin/Admin.php` líneas 68-75  
**Código actual:**
```php
TBOEndpoint::getInstance();
HotelbedsEndpoint::getInstance();
UnifiedHotelEndpoint::getInstance();
BookingSessionEndpoint::getInstance();
```

**Problema:** Agregar un provider con endpoint propio requiere agregar una línea aquí. No es autodetectado.

**Nota:** Esto es normal para WordPress — no hay autoregistro de endpoints. Es un paso del checklist, no un bug.

---

## 🟢 SEVERIDAD BAJA

Hallazgos cosméticos o que ya funcionan correctamente por diseño.

---

### L1 — Provider self-references

Cada provider retorna su nombre hardcoded en `get_provider_name()`. **Correcto por diseño del interface.**

### L2 — Frontend provider formatting

**Archivo:** `assets/scripts/modules/initHotelResults.js` línea 504  
```javascript
providerName === 'tbo' ? 'TBO' : providerName.charAt(0).toUpperCase() + providerName.slice(1)
```
**Estado:** Funciona para cualquier provider. Solo TBO tiene case especial (uppercase completo). Un provider con nombre ≤3 chars se formatearía a UPPERCASE vía `HotelFiltersManager.js:330`.

### L3 — Route defaults `'tbo'`

Las rutas `/booking/detail` y `/booking/cancel` tienen `'default' => 'tbo'` para el param `provider`. **Correcto** — backward-compatible para bookings existentes.

### L4 — `get_booking_session()` inicializa estructura TBO

**Archivo:** `classes/Endpoints/TBO/Endpoint.php` línea 2017  
```php
if (!isset($session['tboBooking']) || !is_array($session['tboBooking'])) {
    $session['tboBooking'] = ['bookingStatus' => 'pending', ...];
}
```
**Estado:** Este guard solo aplica si `tboBooking` no existe. Como H2 lo pre-crea como `[]`, este guard se activa y le da estructura TBO-specific. Para un 3er provider, `tboBooking` ya existe como `[]` (por H2), el guard se activa (evalúa `is_array([])`=true, `isset`=true → NO se activa). Los datos del 3er provider se guardan en `tboBooking` vía H1 sin esta estructura — **funciona correctamente**.

---

## Análisis de bloqueos reales

> **Pregunta:** ¿Cuáles de estos hallazgos son BLOQUEANTES para agregar un 3er provider?

**Respuesta: NINGUNO es bloqueante.** Ver análisis detallado en la sección de abajo y en la respuesta del 2026-02-22.

Todos los hallazgos son deuda técnica que acumula fragilidad pero no impide la operación de un nuevo provider si se sigue el checklist de `NEW-PROVIDER-CHECKLIST.md`.
