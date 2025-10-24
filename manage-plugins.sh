#!/bin/bash

# Script principal para gestionar plugins de WordPress desde el directorio raíz
# Se integra con la configuración de Docker Compose y el tema activo

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_SCRIPTS_DIR="$SCRIPT_DIR/docker/scripts"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}🔌 WordPress Plugin Manager${NC}"
    echo ""
    echo "Gestiona plugins de WordPress para el tema activo configurado en docker-compose"
    echo ""
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos:"
    echo "  install [plugin]     Instala un plugin específico"
    echo "  install-required     Instala todos los plugins requeridos por el tema activo"
    echo "  list                 Lista todos los plugins instalados"
    echo "  activate [plugin]    Activa un plugin"
    echo "  deactivate [plugin]  Desactiva un plugin"
    echo "  remove [plugin]      Elimina un plugin"
    echo "  setup               Configuración inicial completa"
    echo ""
    echo "Opciones:"
    echo "  -h, --help          Mostrar esta ayuda"
    echo "  --force             Forzar operación"
    echo "  --quiet             Modo silencioso"
    echo ""
    echo "Ejemplos:"
    echo "  $0 setup                           # Configuración completa inicial"
    echo "  $0 install-required               # Instala plugins del tema activo"
    echo "  $0 install woocommerce            # Instala WooCommerce"
    echo "  $0 install /path/to/plugin.zip    # Instala desde archivo local"
    echo "  $0 list                           # Lista plugins instalados"
    echo ""
}

# Cargar variables de entorno
load_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        echo -e "${BLUE}🔧 Cargando configuración desde .env${NC}"
        export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
    else
        echo -e "${YELLOW}⚠️  Archivo .env no encontrado${NC}"
        echo -e "${BLUE}💡 Creando archivo .env de ejemplo...${NC}"
        create_sample_env
        echo -e "${RED}❌ Por favor configura el archivo .env antes de continuar${NC}"
        exit 1
    fi
}

# Crear archivo .env de ejemplo
create_sample_env() {
    cat > "$SCRIPT_DIR/.env" << 'EOF'
# Configuración del tema activo
ACTIVE_THEME=emede24

# Configuración de WordPress
WORDPRESS_DB_HOST=db
WORDPRESS_DB_USER=wordpress
WORDPRESS_DB_PASSWORD=wordpress_password
WORDPRESS_DB_NAME=wordpress_db
MYSQL_ROOT_PASSWORD=root_password

# Puertos
WP_PORT=8080
MYSQL_PORT=3306
NGINX_PORT=8081
VITE_PORT=3000

# Desarrollo
VITE_DEV_MODE=true
WP_ENV=development
EOF
}

# Verificar que Docker está ejecutándose
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker no está ejecutándose${NC}"
        echo -e "${BLUE}💡 Por favor inicia Docker Desktop o el demonio de Docker${NC}"
        exit 1
    fi
}

# Verificar y iniciar servicios si es necesario
ensure_services_running() {
    echo -e "${BLUE}🔍 Verificando servicios de Docker...${NC}"
    
    cd "$SCRIPT_DIR"
    
    if ! docker-compose ps wordpress | grep -q "Up"; then
        echo -e "${YELLOW}⚠️  Los servicios no están ejecutándose${NC}"
        echo -e "${BLUE}🚀 Iniciando servicios...${NC}"
        docker-compose up -d
        
        echo -e "${BLUE}⏳ Esperando que los servicios estén listos...${NC}"
        sleep 15
        
        # Verificar que WordPress esté respondiendo
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if docker-compose exec wordpress wp core is-installed --allow-root >/dev/null 2>&1; then
                echo -e "${GREEN}✅ WordPress está listo${NC}"
                break
            fi
            
            echo -e "${BLUE}⏳ Intento $attempt/$max_attempts - Esperando WordPress...${NC}"
            sleep 5
            attempt=$((attempt + 1))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            echo -e "${RED}❌ WordPress no respondió después de $max_attempts intentos${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Los servicios ya están ejecutándose${NC}"
    fi
}

# Ejecutar comando en el contenedor de WordPress
wp_exec() {
    docker-compose exec wordpress "$@"
}

# Comando: instalar plugin específico
cmd_install() {
    local plugin="$1"
    if [ -z "$plugin" ]; then
        echo -e "${RED}❌ Debes especificar un plugin para instalar${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📦 Instalando plugin: $plugin${NC}"
    
    if [[ "$plugin" == *.zip ]] && [[ -f "$plugin" ]]; then
        # Archivo ZIP local
        local container_path="/tmp/$(basename "$plugin")"
        docker cp "$plugin" "$(docker-compose ps -q wordpress):$container_path"
        wp_exec wp plugin install "$container_path" --allow-root
        wp_exec rm -f "$container_path"
    elif [[ "$plugin" =~ ^https?:// ]]; then
        # URL remota
        wp_exec wp plugin install "$plugin" --allow-root
    else
        # Repositorio de WordPress
        wp_exec wp plugin install "$plugin" --allow-root
    fi
    
    echo -e "${GREEN}✅ Plugin $plugin instalado correctamente${NC}"
}

# Comando: instalar plugins requeridos
cmd_install_required() {
    echo -e "${BLUE}🎨 Instalando plugins requeridos para el tema: $ACTIVE_THEME${NC}"
    
    # Copiar el script de instalación al contenedor y ejecutarlo
    docker cp "$DOCKER_SCRIPTS_DIR/install-plugins.sh" "$(docker-compose ps -q wordpress):/tmp/install-plugins.sh"
    wp_exec chmod +x /tmp/install-plugins.sh
    wp_exec /tmp/install-plugins.sh
    wp_exec rm -f /tmp/install-plugins.sh
}

# Comando: listar plugins
cmd_list() {
    echo -e "${BLUE}📋 Plugins instalados:${NC}"
    wp_exec wp plugin list --allow-root
}

# Comando: activar plugin
cmd_activate() {
    local plugin="$1"
    if [ -z "$plugin" ]; then
        echo -e "${RED}❌ Debes especificar un plugin para activar${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔌 Activando plugin: $plugin${NC}"
    wp_exec wp plugin activate "$plugin" --allow-root
    echo -e "${GREEN}✅ Plugin $plugin activado${NC}"
}

# Comando: desactivar plugin
cmd_deactivate() {
    local plugin="$1"
    if [ -z "$plugin" ]; then
        echo -e "${RED}❌ Debes especificar un plugin para desactivar${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔌 Desactivando plugin: $plugin${NC}"
    wp_exec wp plugin deactivate "$plugin" --allow-root
    echo -e "${GREEN}✅ Plugin $plugin desactivado${NC}"
}

# Comando: eliminar plugin
cmd_remove() {
    local plugin="$1"
    if [ -z "$plugin" ]; then
        echo -e "${RED}❌ Debes especificar un plugin para eliminar${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  Eliminando plugin: $plugin${NC}"
    wp_exec wp plugin delete "$plugin" --allow-root
    echo -e "${GREEN}✅ Plugin $plugin eliminado${NC}"
}

# Comando: configuración inicial completa
cmd_setup() {
    echo -e "${BLUE}🚀 Configuración inicial completa del entorno WordPress${NC}"
    
    # Instalar dependencias del tema
    if [ -f "$DOCKER_SCRIPTS_DIR/install-theme-dependencies.sh" ]; then
        echo -e "${BLUE}📦 Instalando dependencias del tema...${NC}"
        docker cp "$DOCKER_SCRIPTS_DIR/install-theme-dependencies.sh" "$(docker-compose ps -q wordpress):/tmp/install-theme-dependencies.sh"
        wp_exec chmod +x /tmp/install-theme-dependencies.sh
        wp_exec /tmp/install-theme-dependencies.sh
        wp_exec rm -f /tmp/install-theme-dependencies.sh
    fi
    
    # Instalar plugins requeridos
    cmd_install_required
    
    # Activar el tema
    echo -e "${BLUE}🎨 Activando tema: $ACTIVE_THEME${NC}"
    wp_exec wp theme activate "$ACTIVE_THEME" --allow-root
    
    echo -e "${GREEN}🎉 ¡Configuración inicial completada!${NC}"
    echo -e "${BLUE}🌐 Tu sitio WordPress está disponible en: http://localhost:${WP_PORT}${NC}"
}

# Procesamiento de argumentos principales
main() {
    # Verificar argumentos
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # Cargar configuración
    load_env
    
    # Verificar prerrequisitos
    check_docker
    
    # Verificar que ACTIVE_THEME está definido
    if [ -z "$ACTIVE_THEME" ]; then
        echo -e "${RED}❌ ACTIVE_THEME no está definido en .env${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🎨 Tema activo: $ACTIVE_THEME${NC}"
    
    # Asegurar que los servicios estén ejecutándose
    ensure_services_running
    
    # Procesar comando
    local command="$1"
    shift
    
    case "$command" in
        "install")
            cmd_install "$@"
            ;;
        "install-required")
            cmd_install_required
            ;;
        "list")
            cmd_list
            ;;
        "activate")
            cmd_activate "$@"
            ;;
        "deactivate")
            cmd_deactivate "$@"
            ;;
        "remove"|"delete")
            cmd_remove "$@"
            ;;
        "setup")
            cmd_setup
            ;;
        *)
            echo -e "${RED}❌ Comando desconocido: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal con todos los argumentos
main "$@"