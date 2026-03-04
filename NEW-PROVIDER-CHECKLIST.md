# New Provider Integration Checklist

> **Propósito:** Pasos necesarios para integrar un tercer provider de hoteles (ej: Expedia, Booking.com) en la arquitectura multi-provider existente.
>
> **Prerequisito:** Leer `PROJECT-CONTEXT.md` y `themes/travel-concierge-me-theme/docs/multi-provider-architecture.md` antes de empezar.
>
> **Última actualización:** 2026-02-22

---

## Fase 1: Implementación del Provider

### 1.1 — Crear la clase del provider

```
themes/travel-concierge-me-theme/classes/Providers/{ProviderName}/
├── {ProviderName}HotelProvider.php    # implements HotelProviderInterface
└── Traits/
    └── {ProviderName}ApiClient.php    # API communication trait
```

- [ ] Crear directorio `classes/Providers/{ProviderName}/`
- [ ] Crear `{ProviderName}HotelProvider.php` implementando `HotelProviderInterface`
- [ ] Implementar los 8 métodos del interface:
  - `search(array $canonical_request): array`
  - `prebook(array $session): array`
  - `book(array $session): array`
  - `cancel(array $params): array`
  - `get_booking_detail(array $params): array`
  - `get_capabilities(): array`
  - `get_provider_name(): string`
  - `get_api_version(): string`
- [ ] Crear `Traits/{ProviderName}ApiClient.php` con la lógica de comunicación HTTP
- [ ] Agregar el trait `CanonicalCache` para L2 caching (ver `classes/Providers/Traits/CanonicalCache.php`)

**Referencia:** Ver `HotelbedsHotelProvider.php` o `TboHotelProvider.php` como ejemplos.

### 1.2 — Registrar en ProviderFactory

**Archivo:** `classes/Providers/ProviderFactory.php`

- [ ] Agregar nuevo `case '{providername}':` en el método `make()`
- [ ] Crear método `private static function make_{providername}()`
- [ ] Verificar que retorna instancia de `HotelProviderInterface`

```php
// En make():
case '{providername}':
    return self::make_{providername}();

// Nuevo método:
private static function make_{providername}(): HotelProviderInterface|WP_Error {
    $api_url = defined('PROVIDERNAME_API_URL') ? PROVIDERNAME_API_URL : '';
    $api_key = defined('PROVIDERNAME_API_KEY') ? PROVIDERNAME_API_KEY : '';
    if (empty($api_url) || empty($api_key)) {
        return new WP_Error('provider_config', 'ProviderName API not configured');
    }
    return new ProviderNameHotelProvider($api_url, $api_key);
}
```

### 1.3 — Registrar en UnifiedHotelEndpoint

**Archivo:** `classes/Endpoints/UnifiedHotelEndpoint.php` (líneas 70-76)

- [ ] Agregar bloque `if (in_array('{providername}', ...))` en `init()`
- [ ] Crear método `init_{providername}_provider()`

```php
// En init():
if (in_array('{providername}', $this->active_providers, true)) {
    $this->init_{providername}_provider();
}

// Nuevo método:
private function init_{providername}_provider(): void {
    $provider = ProviderFactory::make('{providername}');
    if (!is_wp_error($provider)) {
        $this->providers['{providername}'] = $provider;
    }
}
```

---

## Fase 2: Endpoints y Configuración

### 2.1 — Crear endpoint específico del provider (opcional)

**Solo si el provider necesita rutas propias** (ej: webhooks, callbacks de pago).

```
classes/Endpoints/{ProviderName}/Endpoint.php
```

- [ ] Crear endpoint si es necesario (no obligatorio si todo se maneja por el flujo unificado)
- [ ] Registrar en `classes/Admin/Admin.php` → `load_instances()`:

```php
Endpoints\{ProviderName}\Endpoint::getInstance();
```

### 2.2 — Configurar variables de entorno

**Archivo:** `.env` (raíz del proyecto)

- [ ] Agregar variables del nuevo provider:
  ```env
  PROVIDERNAME_API_URL=https://api.providername.com
  PROVIDERNAME_API_KEY=your_key_here
  PROVIDERNAME_API_SECRET=your_secret_here  # si aplica
  ```
- [ ] Agregar el provider a la lista activa:
  ```env
  TCM_ACTIVE_PROVIDERS=tbo,hotelbeds,{providername}
  ```
- [ ] Definir constantes en `inc/env.php`:
  ```php
  define('PROVIDERNAME_API_URL', getenv('PROVIDERNAME_API_URL') ?: '');
  define('PROVIDERNAME_API_KEY', getenv('PROVIDERNAME_API_KEY') ?: '');
  ```

### 2.3 — Pasar variables al container Docker

**Archivo:** `docker-compose.yaml`

- [ ] Agregar env vars al servicio `wordpress`:
  ```yaml
  environment:
    PROVIDERNAME_API_URL: ${PROVIDERNAME_API_URL}
    PROVIDERNAME_API_KEY: ${PROVIDERNAME_API_KEY}
  ```

---

## Fase 3: Datos Canónicos

### 3.1 — Transformaciones canónicas

- [ ] Implementar `transform_to_canonical()` que convierte la respuesta del provider al formato canónico:

```php
// Estructura canónica de hotel (OBLIGATORIO):
[
    'hotelCode'    => string,
    'hotelName'    => string,
    'rating'       => int,        // 1-5 estrellas
    'address'      => string,
    'city'         => string,
    'country'      => string,
    'imageUrl'     => string,     // URL imagen principal
    'coordinates'  => ['lat' => float, 'lon' => float],
    'description'  => string,
    'images'       => array,
    'amenities'    => array,
    'offers'       => [           // Array de ofertas/habitaciones
        [
            'offerId'     => string,
            'roomName'    => string,
            'roomType'    => string,
            'mealType'    => string,
            'totalFare'   => ['amount' => float, 'currency' => string],
            'isRefundable'=> bool,
            'provider'    => '{providername}',
        ]
    ]
]
```

### 3.2 — Transformaciones de búsqueda

- [ ] Implementar traducción de `geonameId` → código de destino del provider
- [ ] Cachear mapeos de países/destinos con `set_transient()` (TTL: 24h-30d)
- [ ] Implementar `transform_canonical_request_to_provider()` para convertir búsqueda canónica → formato del provider

---

## Fase 4: Rebuild y Testing

### 4.1 — Rebuild del autoload

```bash
docker compose exec wordpress bash -c \
  'cd wp-content/themes/travel-concierge-me-theme && composer dump-autoload -o'
```

### 4.2 — Tests funcionales

- [ ] **Search:** Verificar que el nuevo provider aparece en resultados de `/tcm/v1/hotels-search`
- [ ] **Prebook:** Verificar que prebook funciona con `provider: '{providername}'`
- [ ] **Book:** Reservar exitosamente y recibir `bookingId` + `confirmationNo`
- [ ] **Cancel:** Cancelar reserva y verificar respuesta
- [ ] **Detail:** Consultar detalle de reserva existente
- [ ] **Cache L1:** Verificar que raw API responses se cachean (`get_transient`)
- [ ] **Cache L2:** Verificar que datos canónicos se cachean (`[L2-Cache] ⚡ HIT` en logs)

### 4.3 — Tests de resiliencia

```bash
# Simular fallo del nuevo provider
TCM_SIMULATE_PROVIDER_ERRORS={providername} docker compose up -d

# Verificar que otros providers siguen funcionando
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-04-20", "checkOut": "2026-04-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'
```

### 4.4 — Verificación de logs

```bash
# Verificar inicialización
docker logs wordpress-1 --tail 50 | grep "providers:"
# Esperado: "initialized with providers: tbo, hotelbeds, {providername}"

# Verificar search
docker logs wordpress-1 --tail 100 | grep "{ProviderName}"
```

---

## Resumen de archivos a crear/modificar

| Acción | Archivo | Tipo |
|--------|---------|------|
| **Crear** | `classes/Providers/{ProviderName}/{ProviderName}HotelProvider.php` | Provider principal |
| **Crear** | `classes/Providers/{ProviderName}/Traits/{ProviderName}ApiClient.php` | Trait de API |
| **Modificar** | `classes/Providers/ProviderFactory.php` | Agregar case + make method |
| **Modificar** | `classes/Endpoints/UnifiedHotelEndpoint.php` | Agregar init block |
| **Modificar** | `classes/Admin/Admin.php` | Registrar endpoint (si creó uno) |
| **Modificar** | `.env` | Variables del provider |
| **Modificar** | `inc/env.php` | Definir constantes |
| **Modificar** | `docker-compose.yaml` | Pasar env vars al container |

**Total mínimo:** 2 archivos nuevos + 4 archivos modificados (sin endpoint propio).

---

## Notas importantes

1. **NUNCA** agregar columnas provider-specific a tablas compartidas (`tcm_world_cities`, etc.)
2. **SIEMPRE** transformar datos al formato canónico en el boundary del provider
3. **SIEMPRE** agregar el trait `CanonicalCache` para L2 caching
4. **SIEMPRE** usar `sanitize_booking_code()` para tokens opacos del provider (NUNCA `sanitize_text_field()`)
5. **SIEMPRE** cachear mapeos de países/destinos del provider API
6. Ver `NEW-PROVIDER-TECHNICAL-DEBTS.md` para deuda técnica conocida que podría afectar la integración
