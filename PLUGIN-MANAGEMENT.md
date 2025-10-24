# WordPress Plugin Management

Este proyecto incluye varios scripts para gestionar plugins de WordPress de manera automatizada, integrado con Docker y el sistema de temas activos.

## Scripts Disponibles

### 1. Instalación rápida de WP Fastest Cache
```bash
./install-wp-cache.sh
```
Script simple que instala y activa WP Fastest Cache específicamente.

### 2. Gestor completo de plugins
```bash
./manage-plugins.sh [comando] [opciones]
```

Comandos disponibles:
- `setup` - Configuración inicial completa
- `install [plugin]` - Instala un plugin específico
- `install-required` - Instala plugins requeridos por el tema activo
- `list` - Lista plugins instalados
- `activate [plugin]` - Activa un plugin
- `deactivate [plugin]` - Desactiva un plugin
- `remove [plugin]` - Elimina un plugin

### 3. Instalador simple de plugins
```bash
./install-plugin.sh [plugin-name] [opciones]
```

Opciones:
- `--activate` - Activar después de instalar
- `--force` - Forzar reinstalación

## Ejemplos de Uso

### Instalar solo WP Fastest Cache:
```bash
./install-wp-cache.sh
```

### Instalar todos los plugins del tema activo:
```bash
./manage-plugins.sh install-required
```

### Instalar un plugin específico:
```bash
./manage-plugins.sh install woocommerce
./install-plugin.sh contact-form-7 --activate
```

### Configuración inicial completa:
```bash
./manage-plugins.sh setup
```

## Configuración

### Archivo .env
Asegúrate de tener configurado tu archivo `.env` con:
```env
ACTIVE_THEME=emede24
WP_PORT=8080
# ... otras configuraciones
```

### Plugins por Tema

#### Tema emede24
Los plugins que se instalan automáticamente:
- **WP Fastest Cache** - Cache rápido y eficiente
- **Contact Form 7** - Formularios de contacto
- **Advanced Custom Fields** - Campos personalizados
- **Yoast SEO** - Optimización SEO

#### Configuración Personalizada
Cada tema puede tener su archivo `required-plugins.json` en:
```
themes/{THEME_NAME}/required-plugins.json
```

Ejemplo de estructura:
```json
{
  "plugins": [
    {
      "name": "wp-fastest-cache",
      "activate": true,
      "description": "Plugin de cache rápido"
    }
  ]
}
```

## Requisitos

- Docker y Docker Compose
- Bash (WSL en Windows)
- Archivo `.env` configurado
- Tema activo definido en `ACTIVE_THEME`

## Notas Importantes

- Los scripts verifican automáticamente si Docker está ejecutándose
- Si los servicios no están activos, se inician automáticamente
- Los plugins se instalan usando WP-CLI dentro del contenedor
- La configuración se basa en el tema activo definido en `.env`

## Troubleshooting

### Error: ACTIVE_THEME no definido
Verifica tu archivo `.env` y asegúrate de que `ACTIVE_THEME` esté configurado.

### Error: Docker no está ejecutándose
Inicia Docker Desktop o el demonio de Docker antes de ejecutar los scripts.

### Error: Contenedor no encontrado
Ejecuta `docker-compose up -d` para iniciar los servicios.