# WordPress Plugin Management

Sistema simple para instalar plugins de WordPress desde configuración JSON.

## Uso

```bash
./install-plugins.sh
```

Este script:
- Lee el archivo `themes/{ACTIVE_THEME}/required-plugins.json`
- Instala todos los plugins definidos
- Activa los plugins según la configuración
- Maneja automáticamente Docker y WordPress

## Configuración

### Archivo .env
```env
ACTIVE_THEME=emede24
WP_PORT=8080
# ... otras configuraciones
```

### Archivo required-plugins.json
Ubicación: `themes/{ACTIVE_THEME}/required-plugins.json`

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
- Archivo `required-plugins.json` en el tema activo

## Ejemplo

1. Configura tu `.env` con `ACTIVE_THEME=emede24`
2. Edita `themes/emede24/required-plugins.json` 
3. Ejecuta `./install-plugins.sh`

¡Listo!