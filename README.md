# WP Builder - Travel Concierge Me

Este es un proyecto para construcción de temas de WordPress con soporte para Vite para la compilación y el desarrollo de archivos de CSS y JavaScript.

## Características del Proyecto

- **Multi-Provider Hotel Search**: Integración con múltiples proveedores (TBO, Hotelbeds) mediante arquitectura canónica
- **Two-Tier Cache**: Sistema de caché L1 (datos raw) + L2 (formato canónico) para performance óptima
- **Parallel Execution**: Ejecución simultánea de múltiples providers
- **WordPress 6.x** con PHP 8.3 + MySQL 8.0
- **Vite** para compilación rápida de assets (JS/SCSS)
- **Docker Compose** para desarrollo consistente
- **Composer** autoload para clases PHP

> **📖 Documentación completa**: Ver [PROJECT-CONTEXT.md](PROJECT-CONTEXT.md) para arquitectura detallada y [RELEASE-NOTES-2026-02-15.md](themes/travel-concierge-me-theme/docs/RELEASE-NOTES-2026-02-15.md) para el último sprint completado.

## Requisitos

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Instalación

1. **Copia el archivo de plantilla .env:**

    Crea un archivo .env a partir del archivo de plantilla .env.template que se incluye en el repositorio.

    ```bash
    cp .env.template .env
    ```

    Luego, edita el archivo .env con los valores adecuados para tu configuración.

2. **Construye y levanta los contenedores:**

    ```bash
    docker compose up --build
    ```

3. **Instala las dependencias de Vite:**

    En otro terminal, corre:

    ```bash
    docker compose run --rm vite npm install
    ```

4. **Inicia el servidor de desarrollo de Vite:**

    En otro terminal, corre:

    ```bash
    docker compose run --rm vite npm run dev
    ```
    
    Esto iniciará el servidor de desarrollo de Vite, permitiéndote ver los cambios en tiempo real.

5. **Accede a los servicios:**

    WordPress estará accesible en <http://localhost:8000>.

    Nginx servirá el contenido en <http://localhost:8080>.

    Vite para el desarrollo estará disponible en <http://localhost:5173>.

6. **Configuración**

    Las variables de entorno necesarias para WordPress están en el archivo .env. Asegúrate de configurarlas adecuadamente antes de levantar los servicios.

    Ejemplo de archivo .env:

    ```env
    # WordPress & Database
    WORDPRESS_DB_HOST=db
    WORDPRESS_DB_USER=wordpress_user
    WORDPRESS_DB_PASSWORD=wordpress_password
    WORDPRESS_DB_NAME=wordpress_db
    MYSQL_ROOT_PASSWORD=root_password
    
    # Theme Configuration
    ACTIVE_THEME=travel-concierge-me-theme
    WP_PORT=5050
    VITE_PORT=5159
    
    # Multi-Provider Hotel Search
    TCM_ACTIVE_PROVIDERS=hotelbeds,tbo
    
    # Cron reliability (set to true in staging/production)
    TCM_DISABLE_WP_CRON=false
    
    # TBO Holidays API
    TBOH_API_URL=http://api.tbotechnology.in/TBOHolidays_HotelAPI
    TBOH_API_USERNAME=your_username
    TBOH_API_PASSWORD=your_password
    
    # Hotelbeds API
    HOTELBEDS_API_URL=https://api.test.hotelbeds.com
    HOTELBEDS_API_KEY=your_key
    HOTELBEDS_API_SECRET=your_secret
    ```

7. **Desarrollo**

    Para iniciar el servidor de desarrollo de Vite, utiliza:

    ```bash
    docker compose run --rm vite npm run dev
    ```

    Este comando iniciará el servidor de desarrollo de Vite, permitiéndote ver los cambios en tiempo real.

8. Distribución archivos de estilos

   ```plaintext
   styles/
   │
   ├── abstracts/      # Variables, mixins, funciones
   ├── base/           # Estilos base o globales (reset, normalización)
   ├── components/     # Estilos para componentes reutilizables
   ├── layout/         # Estilos de layout (grid, contenedores, etc.)
   ├── pages/          # Estilos específicos para páginas
   ├── themes/         # Temas o configuraciones de estilos
   ├── vendors/        # Estilos de bibliotecas externas
   └── main.scss       # Archivo principal que importa todo
   ```

## Autoload de PHP con Composer (vendor)

Para que se genere la carpeta `vendor/` dentro de tu tema y poder autocargar clases PHP, debes incluir un `composer.json` en el directorio del tema activo y definir el autoload. Este proyecto ya instala Composer dentro del contenedor de WordPress y lo ejecuta automáticamente si detecta el archivo.

1. Crear `composer.json` en tu tema

Colócalo en `themes/<ACTIVE_THEME>/composer.json`. Ejemplo usando classmap para la carpeta `classes/`:

```json
{
    "name": "emede/emede-theme",
    "type": "wordpress-theme",
    "autoload": {
        "classmap": [
            "classes/"
        ]
    }
}
```

1. Crear la carpeta de clases

Dentro de tu tema, crea `classes/` y agrega tus clases PHP, por ejemplo `classes/MyService.php`. Composer indexará esa carpeta y generará el mapa de clases.

1. Requerir el autoloader en el tema

En `functions.php` de tu tema, incluye el autoloader de Composer para habilitar la carga automática de clases:

```php
// functions.php
require_once get_theme_file_path('/vendor/autoload.php');
```

1. Generar `vendor/`

- Automático al levantar WordPress: el servicio `wordpress` ejecuta `composer install` en el tema activo si existe `composer.json` y la variable `ACTIVE_THEME` está definida en `.env`.
- Manual (opcional):

```bash
# Ejecutar dentro del contenedor de WordPress
docker compose exec wordpress bash -lc 'cd /var/www/html/wp-content/themes/$ACTIVE_THEME && composer install --no-dev --optimize-autoloader'
```

1. Actualizar autoload si cambias clases

Si agregas/mueves clases, actualiza el índice de autoload:

```bash
docker compose exec wordpress bash -lc 'cd /var/www/html/wp-content/themes/$ACTIVE_THEME && composer dump-autoload -o'
```

Ejemplo explícito (usa el nombre del tema y la opción `-T` para TTY-less exec):

```bash
docker compose exec -T wordpress sh -lc "cd wp-content/themes/travel-concierge-me-theme && composer dump-autoload -o"
```

Notas:

- Asegúrate de que `.env` tenga `ACTIVE_THEME` apuntando a la carpeta de tu tema (por ejemplo, `ACTIVE_THEME=theme`).
- Si no existe `composer.json` en el tema, no se generará `vendor/` y se saltará la instalación.

## Instalación automática de plugins del tema (WP-CLI)

Este proyecto instala automáticamente los plugins requeridos definidos por tu tema activo usando WP-CLI. La definición se toma de `themes/<ACTIVE_THEME>/required-plugins.json`.

• Cuándo corre

- Al iniciar el contenedor `wordpress`, antes de arrancar Apache, se ejecuta `/usr/local/bin/install-required-plugins.sh`.
- Si WordPress aún no está instalado, el script termina sin error y puedes ejecutarlo manualmente después de completar la instalación.

• Dónde definir los plugins

Coloca un archivo `required-plugins.json` en el directorio del tema activo. Ejemplo mínimo:

```json
{
    "plugins": [
        { "name": "wp-fastest-cache", "activate": true }
    ],
    "configuration": {
        "auto_activate": true,
        "skip_existing": true,
        "update_existing": false,
        "required_plugins": ["wp-fastest-cache"]
    }
}
```

• Cómo se interpreta

- `configuration.required_plugins`: lista prioritaria de slugs a instalar (y su orden). Si no existe, se usan `plugins[].name`.
- `plugins[].activate`: activa por-plugin; tiene prioridad sobre `auto_activate` global.
- `configuration.auto_activate`: activa todos los instalados, salvo que el plugin tenga `activate: false`.
- `configuration.skip_existing`: si es `true`, no reinstala plugins ya presentes (pero puede activarlos si corresponde).
- `configuration.update_existing`: si es `true`, fuerza reinstalación/actualización (`--force`).

• Ejecución manual (Windows PowerShell)

Si necesitas relanzar la instalación tras configurar WordPress o cambiar el JSON:

```powershell
docker compose exec wordpress bash -lc "/usr/local/bin/install-required-plugins.sh"
```

• Requisitos internos

- WP-CLI y `jq` están preinstalados en la imagen de `wordpress` de este proyecto.
- La variable `.env` `ACTIVE_THEME` debe apuntar a la carpeta del tema activo.

## Comandos Útiles del Proyecto

### Hotel Search & Cache Management

```bash
# Test hotel search (Cancún example)
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'

# Clear all WordPress transients (cache)
docker compose exec wordpress wp transient delete --all --quiet

# View hotel search logs (performance monitoring)
docker logs travel-concierge-me-builder-wordpress-1 --tail 100 | grep -E "\[HotelbedsContent|\[TboDetails|\[L2-Cache|\[TCM-Parallel"

# Run database migrations
docker compose exec wordpress wp tcm-migrate
```

### Cron & Async Verification

```bash
# Check cron mode, TCM-managed hooks, and async heartbeat:
docker compose exec wordpress wp tcm-cron status

# Filter to TBO post-book follow-up events:
docker compose exec wordpress wp tcm-cron status --hook=tcm_tbo_post_book_detail_followup

# Read raw heartbeat option (confirms cron executed recently):
docker compose exec wordpress wp option get tcm_async_test_last_run --format=json

# Manually fire any overdue cron events:
docker compose exec wordpress wp cron event run --due-now

# Tail TBO booking log lines:
docker logs travel-concierge-me-builder-wordpress-1 --tail 200 | grep "\[TBOBooking\]"
```

**Cron mode:** By default the project runs WordPress pseudo-cron (events fire when HTTP traffic hits the site). For staging and production reliability — especially the TBO 120-second BookingDetail follow-up — set `TCM_DISABLE_WP_CRON=true` in `.env` and configure a system cron to call `wp-cron.php` every minute. See `themes/travel-concierge-me-theme/docs/dev-docs/2026-03-22-production-cron-setup.md` for the full runbook.

### Asset Development

```bash
# Development (Vite hot reload)
docker compose up -d vite

# Production build
docker compose run --rm vite npm run build

# Watch logs
docker compose logs -f vite
```

### PHP Class Management

```bash
# Rebuild Composer autoload after adding/moving classes
docker compose exec wordpress bash -lc 'cd /var/www/html/wp-content/themes/$ACTIVE_THEME && composer dump-autoload -o'

# Check PHP errors
docker logs travel-concierge-me-builder-wordpress-1 --tail 50
```

### Performance Benchmarking

```bash
# Check response time with jq
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}' \
  | jq '.meta.performanceMs'

# Expected results:
# - Cold search (first time): ~24,233ms (must populate L1 + L2 cache)
# - Warm search (cached): ~2,535ms (89.5% faster)
```

### Multi-Provider Resilience Testing

```bash
# Test graceful degradation - simulate TBO failure
TCM_SIMULATE_PROVIDER_ERRORS=tbo docker compose up -d
curl -X POST http://localhost:5050/wp-json/tcm/v1/hotels-search \
  -H "Content-Type: application/json" \
  -d '{"geonameId": 3531673, "checkIn": "2026-03-20", "checkOut": "2026-03-22", "nationality": "MX", "paxRooms": [{"adults": 2}]}'
# Expected: Hotelbeds results + TBO error in meta.providerErrors

# Verify simulation in logs
docker logs travel-concierge-me-builder-wordpress-1 --tail 50 | grep "🎭"
# Expected: "🎭 Simulating tbo error (forced tbo failure)"

# Test random failures (50% chance)
TCM_SIMULATE_PROVIDER_ERRORS=random docker compose up -d
# Run multiple searches - some succeed, some fail randomly

# Restore normal operation
TCM_SIMULATE_PROVIDER_ERRORS=none docker compose up -d
```

**Simulation Modes**:
- `none` - Normal operation (default)
- `random` - 50% chance each provider fails
- `tbo` - TBO always fails (test Hotelbeds solo)
- `hotelbeds` - Hotelbeds always fails (test TBO solo)

**What to verify**:
- ✅ Frontend displays results from successful provider
- ✅ Failed provider error appears in `meta.providerErrors`
- ✅ Response time < 30s (individual provider timeout)
- ✅ No AbortError in browser console

## Envío de correos en desarrollo (Mailpit + WP Mail SMTP)

El proyecto está preparado para usar un contenedor `mailer` basado en [Mailpit](https://github.com/axllent/mailpit) como servidor SMTP de desarrollo. Esto permite capturar todos los correos que envía WordPress sin que salgan a Internet.

### Configuración en Docker

En el `docker-compose.yml` se define un servicio similar a:

```yaml
mailer:
  image: axllent/mailpit
  restart: unless-stopped
  ports:
    - "8025:8025"   # UI web de Mailpit (bandeja de prueba)
    - "1025:1025"   # Puerto SMTP usado por WordPress
```

WordPress y `mailer` comparten la misma red de Docker, por lo que desde WordPress el host `mailer` se resuelve automáticamente al contenedor de Mailpit.

### Configuración en WP Mail SMTP

Dentro del panel de WordPress:

1. Ve a **WP Mail SMTP → Settings**.
2. En la sección **Mailer**, selecciona **Other SMTP**.
3. En la sección **Other SMTP**, configura:

   - **SMTP Host:** `mailer`
   - **SMTP Port:** `1025`
   - **Encryption:** `None`
   - **Authentication:** OFF

Guarda los cambios y usa la pestaña **Email Test** para enviar un correo de prueba. Si ves el mensaje **Success!**, WordPress ha entregado el correo correctamente al contenedor `mailer`.

### Dónde se ven los correos

En desarrollo, los correos **no llegarán a tu bandeja real (Gmail, Outlook, etc.)**. Se quedan capturados en Mailpit.

Para verlos, abre en tu navegador:

- <http://localhost:8025>

Ahí aparecerán todos los correos enviados por WordPress (incluido el test de WP Mail SMTP).

### Enviar correos a una bandeja real

Si quieres que los correos lleguen a una bandeja de entrada real (producción):

- Configura WP Mail SMTP para usar un proveedor SMTP real (por ejemplo SendGrid, Brevo, Mailgun, Gmail/Workspace o el SMTP de tu hosting), **en lugar** de `Other SMTP` con `mailer`, o
- Configura Mailpit como relay hacia un SMTP externo (configuración avanzada y fuera del alcance de este README).

De esta forma, en local puedes trabajar de forma segura con Mailpit y, en producción, cambiar solo la configuración de WP Mail SMTP para usar un servidor SMTP real sin modificar el código del tema ni de los plugins.

## Release y Empaquetado de Temas

### Crear ZIP para Producción

Para empaquetar el tema activo y subirlo a producción:

```bash
sh ./themes/<ACTIVE_THEME>/scripts/package-theme.sh
```

Este script automáticamente:

1. Compila assets (Vite + Gutenberg blocks)
2. **Valida manifest.json** para prevenir errores de CSS/JS en producción
3. Excluye archivos de desarrollo (.vite, node_modules, etc.)
4. Crea ZIP optimizado en la raíz del tema

### Validación de Manifest (Preventivo)

El sistema incluye validación automática que previene un bug crítico donde los estilos no cargan en producción debido a mismatch de keys en `manifest.json`.

**Script de validación:**

```bash
bash ./themes/<ACTIVE_THEME>/scripts/validate-manifest.sh
```

**Qué valida:**

- Keys CSS/JS en `manifest.json` coinciden con las usadas en `Enqueue.php`
- Archivos compilados existen físicamente en `assets/dist/`
- Reporta tamaños de archivo para auditoría

**Regla importante:** En `Enqueue.php`, usar **extensiones fuente** (`.scss`, `.js`) no extensiones compiladas (`.css`, `.min.js`):

```php
// ✅ Correcto
tcm_get_asset('styles/front.scss')

// ❌ Incorrecto
tcm_get_asset('styles/front.css')
```

### Checklist Pre-Release

- [ ] Ejecutar `tcm-build` (alias de docker compose para compilar assets)
- [ ] Verificar que validación pasa (se ejecuta automáticamente en package-theme.sh)
- [ ] Probar ZIP en staging si está disponible
- [ ] Subir a producción

**Documentación completa:** Ver `themes/<ACTIVE_THEME>/PREVENTIVE-MEASURES.md` y `themes/<ACTIVE_THEME>/docs/manifest-keys-reference.md`

---

## 📚 Documentación del Proyecto

### Arquitectura y Desarrollo

- **[PROJECT-CONTEXT.md](PROJECT-CONTEXT.md)** - Arquitectura completa del proyecto
  - Stack overview (Docker, WordPress, Vite, PHP)
  - Multi-Provider Hotel Search (TBO, Hotelbeds)
  - Two-Tier Cache (L1 + L2)
  - Parallel execution con Guzzle
  - Canonical format y transformations
  - Classes structure y lifecycle
  - Frontend utilities (TextNormalizer, HotelFiltersManager)

### Tareas y Sprints

**✅ Último Sprint Completado: Hotelbeds PreBook Integration (Feb 15, 2026)**
- ✅ Cancellation policies normalizadas (Hotelbeds → Canonical)
- ✅ Hotel norms extraídas de `rateComments` (20-40% más rápido)
- ✅ Supplements extraídos de taxes no incluidos
- ✅ Multi-provider prebook architecture validada
- 📋 Ver [RELEASE-NOTES-2026-02-15.md](themes/travel-concierge-me-theme/docs/RELEASE-NOTES-2026-02-15.md) para detalles completos

**Sprints Anteriores:**
- ✅ Performance Optimization Sprint (Feb 10-11, 2026)
  - 89.5% mejora en warm searches (24,233ms → 2,535ms)
  - SmartCache pattern, L2 canonical cache, parallel execution
- ✅ Multi-Provider Search Integration (Feb 2026)
  - TBO + Hotelbeds search integrados
  - Canonical format architecture
  - Parallel execution con Guzzle

### Documentación del Tema

Dentro de `themes/travel-concierge-me-theme/docs/`:

- **Arquitectura**:
  - `multi-provider-architecture.md` - Diseño multi-proveedor
  - `endpoints-architecture.md` - REST API endpoints
  - `database-architecture.md` - Estructura de base de datos
  - `class-loading-architecture.md` - Composer autoload y lifecycle

- **Hotelbeds Integration**:
  - `RELEASE-NOTES-2026-02-15.md` - Sprint completo (policies, norms, supplements)
  - `hotelbeds-prebook-implementation-summary.md` - Resumen técnico
  - `hotelbeds-prebook-fixes-2026-02-15.md` - Reporte final del sprint

- **Frontend**:
  - `bem-conventions.md` - Metodología BEM
  - `scss-architecture.md` - Estructura SCSS (abstracts/base/components/layout)
  - `html-template-guidelines.md` - Estándares de templates

- **Performance**:
  - `api-performance-monitoring.md` - Métricas y monitoreo
  - `hotelbeds-implementation-analysis.md` - Análisis Hotelbeds

- **Testing**:
  - `endpoint-testing-guide.md` - Guía de testing de endpoints
  - `database-quick-reference.md` - Referencia rápida de DB

### Performance Actual (Feb 12, 2026)

```
Cold search:  ~24,233ms (primera vez, popula L1 + L2 cache)
Warm search:  ~2,535ms  (89.5% más rápido ⚡)
API calls:    16 → 3    (81% reducción)
Execution:    parallel (TBO + Hotelbeds simultáneo)
Cache layers: L1 (raw 30d/24h) + L2 (canonical 7d)
```

### Soporte

Para preguntas sobre arquitectura o implementación, consultar:
1. PROJECT-CONTEXT.md (arquitectura general)
2. TODO.md (tareas actuales)
3. Documentación específica en `themes/<ACTIVE_THEME>/docs/`
