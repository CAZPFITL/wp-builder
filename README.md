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
    <br><br>

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
    <br><br>

5. **Accede a los servicios:**

    WordPress estará accesible en http://localhost:8000.

    Nginx servirá el contenido en http://localhost:8080.

    Vite para el desarrollo estará disponible en http://localhost:5173.
    <br><br>

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
    <br><br>

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
