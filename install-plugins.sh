#!/bin/bash

# Script simple para instalar plugins desde required-plugins.json
# Uso: ./install-plugins.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Instalando plugins desde required-plugins.json${NC}"

# Cargar variables de entorno
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Verificar ACTIVE_THEME
if [ -z "$ACTIVE_THEME" ]; then
    echo -e "${RED}❌ Error: ACTIVE_THEME no definido en .env${NC}"
    exit 1
fi

echo -e "${GREEN}🎨 Tema activo: ${ACTIVE_THEME}${NC}"

# Verificar archivo de configuración
PLUGINS_CONFIG="./themes/${ACTIVE_THEME}/required-plugins.json"
if [ ! -f "$PLUGINS_CONFIG" ]; then
    echo -e "${RED}❌ Error: No existe $PLUGINS_CONFIG${NC}"
    exit 1
fi

# Iniciar servicios si no están activos
if ! docker-compose ps wordpress | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  Iniciando servicios...${NC}"
    docker-compose up -d
    echo -e "${BLUE}⏳ Esperando WordPress...${NC}"
    sleep 15
fi

# Verificar contenedor
CONTAINER_NAME=$(docker-compose ps -q wordpress)
if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}❌ Error: Contenedor no encontrado${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Procesando plugins desde configuración...${NC}"

# Instalar jq si no existe
docker-compose exec wordpress bash -c "
    if ! which jq >/dev/null 2>&1; then
        echo 'Instalando jq...'
        apt-get update && apt-get install -y jq
    fi
"

# Copiar configuración al contenedor
docker cp "$PLUGINS_CONFIG" "${CONTAINER_NAME}:/tmp/plugins.json"

# Procesar e instalar plugins
docker-compose exec wordpress bash -c "
    cd /var/www/html
    echo '📋 Plugins a instalar:'
    jq -r '.plugins[] | \"  - \(.name) (activate: \(.activate))\"' /tmp/plugins.json
    echo ''
    
    jq -r '.plugins[] | \"\(.name)|\(.activate)\"' /tmp/plugins.json | while IFS='|' read -r name activate; do
        echo \"🔄 Procesando: \$name\"
        
        if wp plugin is-installed \"\$name\" --allow-root >/dev/null 2>&1; then
            echo \"✅ \$name ya instalado\"
            if [ \"\$activate\" = \"true\" ] && ! wp plugin is-active \"\$name\" --allow-root >/dev/null 2>&1; then
                echo \"🔌 Activando \$name...\"
                wp plugin activate \"\$name\" --allow-root
            fi
        else
            echo \"📥 Instalando \$name...\"
            if wp plugin install \"\$name\" --allow-root; then
                echo \"✅ \$name instalado\"
                if [ \"\$activate\" = \"true\" ]; then
                    echo \"🔌 Activando \$name...\"
                    wp plugin activate \"\$name\" --allow-root
                fi
            else
                echo \"❌ Error instalando \$name\"
            fi
        fi
        echo ''
    done
    
    rm -f /tmp/plugins.json
"

echo -e "${BLUE}📊 Plugins activos:${NC}"
docker-compose exec wordpress wp plugin list --status=active --allow-root

echo -e "${GREEN}🎉 ¡Instalación completada!${NC}"
echo -e "${BLUE}🌐 Sitio: http://localhost:${WP_PORT:-8080}${NC}"