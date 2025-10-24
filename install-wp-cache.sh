#!/bin/bash

# Script simple para instalar WP Fastest Cache
# Uso: ./install-wp-cache.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Instalando WP Fastest Cache${NC}"

# Cargar variables de entorno si existe .env
if [ -f ".env" ]; then
    echo -e "${BLUE}🔧 Cargando variables de entorno${NC}"
    export $(grep -v '^#' .env | xargs)
fi

# Verificar que ACTIVE_THEME está definido
if [ -z "$ACTIVE_THEME" ]; then
    echo -e "${RED}❌ Error: ACTIVE_THEME no está definido en .env${NC}"
    exit 1
fi

echo -e "${GREEN}🎨 Tema activo: ${ACTIVE_THEME}${NC}"

# Verificar que Docker Compose está ejecutándose
if ! docker-compose ps wordpress | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  Iniciando servicios de Docker...${NC}"
    docker-compose up -d
    echo -e "${BLUE}⏳ Esperando que WordPress esté listo...${NC}"
    sleep 15
fi

# Verificar que el contenedor está disponible
CONTAINER_NAME=$(docker-compose ps -q wordpress)
if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}❌ Error: Contenedor de WordPress no encontrado${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Instalando WP Fastest Cache...${NC}"

# Instalar el plugin
docker-compose exec wordpress bash -c "
    cd /var/www/html &&
    echo '📥 Descargando WP Fastest Cache...' &&
    wp plugin install wp-fastest-cache --allow-root &&
    echo '🔌 Activando WP Fastest Cache...' &&
    wp plugin activate wp-fastest-cache --allow-root
"

# Verificar instalación
echo -e "${BLUE}📋 Verificando instalación...${NC}"
docker-compose exec wordpress bash -c "
    cd /var/www/html &&
    wp plugin list --status=active --allow-root | grep wp-fastest-cache
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ¡WP Fastest Cache instalado y activado correctamente!${NC}"
    echo -e "${BLUE}💡 Puedes acceder a la configuración en: Admin > WP Fastest Cache${NC}"
    echo -e "${BLUE}🌐 Tu sitio está en: http://localhost:${WP_PORT:-8080}${NC}"
else
    echo -e "${RED}❌ Error en la instalación${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 ¡Instalación completada!${NC}"