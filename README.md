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

Notas:

- Asegúrate de que `.env` tenga `ACTIVE_THEME` apuntando a la carpeta de tu tema (por ejemplo, `ACTIVE_THEME=theme`).
- Si no existe `composer.json` en el tema, no se generará `vendor/` y se saltará la instalación.
