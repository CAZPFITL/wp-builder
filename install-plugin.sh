#!/bin/bash

# Script para instalar plugins de WordPress desde el directorio raíz
# Uso: ./install-plugin.sh [plugin-name] [plugin-source]
# Ejemplos:
#   ./install-plugin.sh woocommerce          # Instala desde WordPress.org
#   ./install-plugin.sh custom-plugin.zip   # Instala desde archivo ZIP local
#   ./install-plugin.sh https://example.com/plugin.zip  # Instala desde URL

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}📦 WordPress Plugin Installer${NC}"
    echo ""
    echo "Uso: $0 [plugin-name-or-source] [options]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  --activate     Activar el plugin después de instalar"
    echo "  --force        Forzar reinstalación si ya existe"
    echo ""
    echo "Ejemplos:"
    echo "  $0 woocommerce                                    # Desde WordPress.org"
    echo "  $0 custom-plugin.zip                             # Desde archivo ZIP local"
    echo "  $0 https://example.com/plugin.zip               # Desde URL remota"
    echo "  $0 woocommerce --activate                        # Instalar y activar"
    echo ""
}

# Verificar argumentos
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

PLUGIN_SOURCE="$1"
ACTIVATE_PLUGIN=false
FORCE_INSTALL=false

# Procesar argumentos adicionales
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --activate)
            ACTIVATE_PLUGIN=true
            shift
            ;;
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            echo -e "${RED}❌ Argumento desconocido: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Cargar variables de entorno si existe .env
if [ -f ".env" ]; then
    echo -e "${BLUE}🔧 Cargando variables de entorno desde .env${NC}"
    export $(grep -v '^#' .env | xargs)
fi

# Verificar que ACTIVE_THEME está definido
if [ -z "$ACTIVE_THEME" ]; then
    echo -e "${RED}❌ Error: ACTIVE_THEME no está definido${NC}"
    echo "   Asegúrate de que esté configurado en tu archivo .env"
    exit 1
fi

echo -e "${GREEN}🎨 Tema activo: ${ACTIVE_THEME}${NC}"

# Verificar que Docker Compose está ejecutándose
if ! docker-compose ps wordpress | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  El contenedor de WordPress no está ejecutándose${NC}"
    echo -e "${BLUE}🚀 Iniciando servicios de Docker...${NC}"
    docker-compose up -d
    echo -e "${BLUE}⏳ Esperando que WordPress esté listo...${NC}"
    sleep 10
fi

CONTAINER_NAME=$(docker-compose ps -q wordpress)
if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}❌ Error: No se pudo encontrar el contenedor de WordPress${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Instalando plugin: ${PLUGIN_SOURCE}${NC}"

# Función para instalar plugin desde WordPress.org
install_from_repo() {
    local plugin_name="$1"
    echo -e "${BLUE}📥 Descargando ${plugin_name} desde WordPress.org...${NC}"
    
    docker-compose exec wordpress bash -c "
        cd /var/www/html &&
        wp plugin install ${plugin_name} ${FORCE_INSTALL:+--force} --allow-root
    "
}

# Función para instalar plugin desde archivo ZIP
install_from_zip() {
    local zip_file="$1"
    local container_path="/tmp/$(basename "$zip_file")"
    
    echo -e "${BLUE}📁 Copiando archivo ZIP al contenedor...${NC}"
    docker cp "$zip_file" "${CONTAINER_NAME}:${container_path}"
    
    echo -e "${BLUE}📦 Instalando desde archivo ZIP...${NC}"
    docker-compose exec wordpress bash -c "
        cd /var/www/html &&
        wp plugin install ${container_path} ${FORCE_INSTALL:+--force} --allow-root &&
        rm -f ${container_path}
    "
}

# Función para instalar plugin desde URL
install_from_url() {
    local url="$1"
    local filename="/tmp/$(basename "$url")"
    
    echo -e "${BLUE}🌐 Descargando plugin desde URL...${NC}"
    docker-compose exec wordpress bash -c "
        cd /var/www/html &&
        wget -O ${filename} '${url}' &&
        wp plugin install ${filename} ${FORCE_INSTALL:+--force} --allow-root &&
        rm -f ${filename}
    "
}

# Determinar el tipo de instalación y ejecutar
if [[ "$PLUGIN_SOURCE" =~ ^https?:// ]]; then
    # Es una URL
    install_from_url "$PLUGIN_SOURCE"
elif [[ "$PLUGIN_SOURCE" == *.zip ]] && [[ -f "$PLUGIN_SOURCE" ]]; then
    # Es un archivo ZIP local
    install_from_zip "$PLUGIN_SOURCE"
elif [[ "$PLUGIN_SOURCE" == *.zip ]] && [[ ! -f "$PLUGIN_SOURCE" ]]; then
    echo -e "${RED}❌ Error: El archivo ZIP no existe: $PLUGIN_SOURCE${NC}"
    exit 1
else
    # Asumir que es un plugin del repositorio de WordPress.org
    install_from_repo "$PLUGIN_SOURCE"
fi

# Activar plugin si se solicitó
if [ "$ACTIVATE_PLUGIN" = true ]; then
    echo -e "${BLUE}🔌 Activando plugin...${NC}"
    
    # Obtener el nombre del plugin para activar
    if [[ "$PLUGIN_SOURCE" == *.zip ]]; then
        # Para archivos ZIP, necesitamos obtener el directorio del plugin
        PLUGIN_DIR=$(docker-compose exec wordpress bash -c "
            cd /var/www/html/wp-content/plugins &&
            ls -1t | head -1
        " | tr -d '\r')
        
        docker-compose exec wordpress bash -c "
            cd /var/www/html &&
            wp plugin activate ${PLUGIN_DIR} --allow-root
        "
    else
        # Para plugins del repositorio, usar el nombre directamente
        docker-compose exec wordpress bash -c "
            cd /var/www/html &&
            wp plugin activate ${PLUGIN_SOURCE} --allow-root
        "
    fi
fi

# Mostrar plugins instalados
echo -e "${GREEN}✅ Instalación completada${NC}"
echo -e "${BLUE}📋 Plugins actualmente instalados:${NC}"
docker-compose exec wordpress bash -c "
    cd /var/www/html &&
    wp plugin list --allow-root
"

echo -e "${GREEN}🎉 ¡Plugin instalado exitosamente en el tema ${ACTIVE_THEME}!${NC}"