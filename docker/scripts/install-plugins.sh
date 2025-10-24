#!/bin/bash

# Script para instalar plugins de WordPress específicos para el tema activo
# Este script se ejecuta dentro del contexto de Docker y maneja la instalación
# de plugins que son específicos o requeridos por el tema activo

set -e

# Configuración de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔌 WordPress Plugin Manager para tema activo${NC}"

# Verificar que ACTIVE_THEME está definido
if [ -z "$ACTIVE_THEME" ]; then
    echo -e "${RED}❌ Error: ACTIVE_THEME no está definido${NC}"
    exit 1
fi

THEME_DIR="/var/www/html/wp-content/themes/$ACTIVE_THEME"
PLUGINS_CONFIG="$THEME_DIR/required-plugins.json"

echo -e "${GREEN}🎨 Tema activo: $ACTIVE_THEME${NC}"
echo -e "${BLUE}📁 Directorio del tema: $THEME_DIR${NC}"

# Verificar que el directorio del tema existe
if [ ! -d "$THEME_DIR" ]; then
    echo -e "${RED}❌ Error: El directorio del tema no existe: $THEME_DIR${NC}"
    exit 1
fi

# Función para instalar plugin individual
install_plugin() {
    local plugin_name="$1"
    local plugin_source="${2:-$1}"
    local should_activate="${3:-false}"
    
    echo -e "${BLUE}📦 Procesando plugin: $plugin_name${NC}"
    
    # Verificar si el plugin ya está instalado
    if wp plugin is-installed "$plugin_name" --allow-root 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Plugin $plugin_name ya está instalado${NC}"
        if [ "$should_activate" = "true" ] && ! wp plugin is-active "$plugin_name" --allow-root 2>/dev/null; then
            echo -e "${BLUE}🔌 Activando plugin $plugin_name...${NC}"
            wp plugin activate "$plugin_name" --allow-root
        fi
        return 0
    fi
    
    # Instalar el plugin
    if [[ "$plugin_source" =~ ^https?:// ]]; then
        echo -e "${BLUE}🌐 Instalando desde URL: $plugin_source${NC}"
        wp plugin install "$plugin_source" --allow-root
    elif [[ "$plugin_source" == *.zip ]]; then
        echo -e "${BLUE}📁 Instalando desde archivo: $plugin_source${NC}"
        wp plugin install "$plugin_source" --allow-root
    else
        echo -e "${BLUE}📥 Instalando desde repositorio: $plugin_source${NC}"
        wp plugin install "$plugin_source" --allow-root
    fi
    
    # Activar si se requiere
    if [ "$should_activate" = "true" ]; then
        echo -e "${BLUE}🔌 Activando plugin $plugin_name...${NC}"
        wp plugin activate "$plugin_name" --allow-root
    fi
    
    echo -e "${GREEN}✅ Plugin $plugin_name instalado correctamente${NC}"
}

# Verificar si existe un archivo de configuración de plugins requeridos
if [ -f "$PLUGINS_CONFIG" ]; then
    echo -e "${BLUE}📋 Procesando plugins requeridos desde: $PLUGINS_CONFIG${NC}"
    
    # Leer y procesar el archivo JSON de plugins requeridos
    if command -v jq >/dev/null 2>&1; then
        # Usar jq si está disponible
        jq -r '.plugins[] | "\(.name)|\(.source // .name)|\(.activate // false)"' "$PLUGINS_CONFIG" | while IFS='|' read -r name source activate; do
            install_plugin "$name" "$source" "$activate"
        done
    else
        # Fallback manual si jq no está disponible
        echo -e "${YELLOW}⚠️  jq no está disponible, usando procesamiento manual${NC}"
        # Aquí podrías agregar un parser manual para JSON simple
        echo -e "${BLUE}💡 Por favor instala jq o especifica los plugins manualmente${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No se encontró $PLUGINS_CONFIG${NC}"
    echo -e "${BLUE}💡 Creando archivo de ejemplo...${NC}"
    
    # Crear archivo de ejemplo
    cat > "$PLUGINS_CONFIG" << 'EOF'
{
  "plugins": [
    {
      "name": "woocommerce",
      "activate": true,
      "description": "Plugin de eCommerce requerido por el tema"
    },
    {
      "name": "advanced-custom-fields",
      "activate": true,
      "description": "Campos personalizados para el tema"
    },
    {
      "name": "custom-plugin",
      "source": "/path/to/custom-plugin.zip",
      "activate": true,
      "description": "Plugin personalizado del tema"
    }
  ]
}
EOF
    
    echo -e "${GREEN}✅ Archivo de configuración creado en: $PLUGINS_CONFIG${NC}"
    echo -e "${BLUE}📝 Edita este archivo para especificar los plugins requeridos por tu tema${NC}"
fi

# Función para instalar plugins específicos del tema emede24
install_emede24_plugins() {
    echo -e "${BLUE}🏠 Instalando plugins específicos para el tema emede24...${NC}"
    
    # Plugin de cache principal - WP Fastest Cache
    install_plugin "wp-fastest-cache" "wp-fastest-cache" true
    
    # Plugins típicos para un tema inmobiliario
    install_plugin "contact-form-7" "contact-form-7" true
    install_plugin "advanced-custom-fields" "advanced-custom-fields" true
    install_plugin "yoast-seo" "wordpress-seo" true
    
    echo -e "${GREEN}✅ Plugins específicos de emede24 instalados${NC}"
}

# Función para instalar plugins específicos del tema build-theme
install_build_theme_plugins() {
    echo -e "${BLUE}🔧 Instalando plugins para el tema de desarrollo...${NC}"
    
    # Plugins útiles para desarrollo
    install_plugin "query-monitor" "query-monitor" true
    install_plugin "debug-bar" "debug-bar" true
    install_plugin "wp-cli" "wp-cli" false
    
    echo -e "${GREEN}✅ Plugins de desarrollo instalados${NC}"
}

# Si se pasan argumentos, instalar plugins específicos
if [ $# -gt 0 ]; then
    echo -e "${BLUE}📦 Instalando plugins especificados como argumentos...${NC}"
    for plugin in "$@"; do
        install_plugin "$plugin"
    done
else
    # Instalar plugins específicos según el tema activo
    case "$ACTIVE_THEME" in
        "emede24")
            install_emede24_plugins
            ;;
        "build-theme")
            install_build_theme_plugins
            ;;
        *)
            echo -e "${YELLOW}⚠️  Tema '$ACTIVE_THEME' no tiene configuración específica de plugins${NC}"
            echo -e "${BLUE}💡 Puedes agregar plugins manualmente o crear un archivo required-plugins.json${NC}"
            ;;
    esac
fi

# Mostrar resumen final
echo -e "${BLUE}📊 Estado final de plugins:${NC}"
wp plugin list --allow-root

echo -e "${GREEN}🎉 ¡Instalación de plugins completada para el tema $ACTIVE_THEME!${NC}"