# WP Builder

Este es un proyecto para construccion de temas de WordPress con soporte para Vite para la compilación y el desarrollo de archivos de CSS y JavaScript.

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
    WORDPRESS_DB_HOST=db
    WORDPRESS_DB_USER=wordpress_user
    WORDPRESS_DB_PASSWORD=wordpress_password
    WORDPRESS_DB_NAME=wordpress_db
    MYSQL_ROOT_PASSWORD=root_password
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
