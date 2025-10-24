#!/bin/bash

# Instala plugins de WordPress definidos en required-plugins.json del tema activo usando WP-CLI.
#
# Requisitos:
#  - WP-CLI disponible en /usr/local/bin/wp
#  - jq instalado
#  - Variable de entorno ACTIVE_THEME definida con el nombre del tema
#  - WordPress accesible en /var/www/html
#
# Comportamiento:
#  - Lee themes/<ACTIVE_THEME>/required-plugins.json
#  - Respeta configuration.required_plugins (orden/selección)
#  - Si no hay required_plugins, usa plugins[].name
#  - Respeta flags: auto_activate, skip_existing, update_existing
#  - También respeta plugins[].activate (tiene prioridad sobre auto_activate)

set -euo pipefail

export WP_CLI_ALLOW_ROOT=${WP_CLI_ALLOW_ROOT:-1}
WP_PATH="/var/www/html"

if ! command -v wp >/dev/null 2>&1; then
  echo "❌ Error: WP-CLI no está instalado (comando 'wp' no encontrado)"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ Error: 'jq' no está instalado y es requerido para leer JSON"
  exit 1
fi

ACTIVE_THEME=${ACTIVE_THEME:-}
if [ -z "$ACTIVE_THEME" ]; then
  echo "❌ Error: La variable de entorno ACTIVE_THEME no está definida"
  exit 1
fi

THEME_DIR="$WP_PATH/wp-content/themes/$ACTIVE_THEME"
JSON_FILE="$THEME_DIR/required-plugins.json"

if [ ! -f "$JSON_FILE" ]; then
  echo "⚠️  Advertencia: No se encontró $JSON_FILE. Nada que instalar."
  exit 0
fi

echo "🔎 Leyendo plugins requeridos desde: $JSON_FILE"

# Lee flags globales con valores por defecto
AUTO_ACTIVATE=$(jq -r '.configuration.auto_activate // false' "$JSON_FILE")
SKIP_EXISTING=$(jq -r '.configuration.skip_existing // true' "$JSON_FILE")
UPDATE_EXISTING=$(jq -r '.configuration.update_existing // false' "$JSON_FILE")

# Construye la lista de slugs a instalar: configuration.required_plugins o plugins[].name
readarray -t REQUIRED_SLUGS < <(jq -r '.configuration.required_plugins[]? // empty' "$JSON_FILE") || true
if [ ${#REQUIRED_SLUGS[@]} -eq 0 ]; then
  readarray -t REQUIRED_SLUGS < <(jq -r '.plugins[].name // empty' "$JSON_FILE") || true
fi

if [ ${#REQUIRED_SLUGS[@]} -eq 0 ]; then
  echo "ℹ️  No se encontraron slugs de plugins para instalar en el JSON."
  exit 0
fi

# Helper: retorna "true"/"false" si en plugins[] existe el slug y tiene activate definido; si no, devuelve vacío
get_per_plugin_activate() {
  local slug="$1"
  jq -r --arg slug "$slug" '
    .plugins[]? | select(.name==$slug) | .activate // empty
  ' "$JSON_FILE" | head -n1
}

# Espera opcionalmente a que WordPress esté instalado; si no lo está, continua con mensaje (no error)
echo "⏳ Verificando si WordPress está instalado (wp core is-installed)..."
if wp --path="$WP_PATH" core is-installed >/dev/null 2>&1; then
  echo "✅ WordPress detectado como instalado. Procediendo a instalar plugins."
else
  echo "⚠️  WordPress no parece estar instalado aún."
  echo "    Este script requiere una instalación activa para usar 'wp plugin install'."
  echo "    Saliendo sin error. Puedes ejecutar este script manualmente después de instalar WordPress."
  exit 0
fi

echo "📦 Instalando plugins requeridos: ${REQUIRED_SLUGS[*]}"

for slug in "${REQUIRED_SLUGS[@]}"; do
  [ -n "$slug" ] || continue

  # Determina si activar: prioridad al flag del plugin; si no existe, usa auto_activate global
  PER_PLUGIN_ACTIVATE=$(get_per_plugin_activate "$slug")
  case "$PER_PLUGIN_ACTIVATE" in
    true|false) SHOULD_ACTIVATE="$PER_PLUGIN_ACTIVATE" ;;
    *) SHOULD_ACTIVATE="$AUTO_ACTIVATE" ;;
  esac

  echo "→ Plugin: $slug (activar=${SHOULD_ACTIVATE})"

  if [ "$SKIP_EXISTING" = "true" ] && wp --path="$WP_PATH" plugin is-installed "$slug" >/dev/null 2>&1; then
    echo "   • Ya instalado."
    # Si está instalado pero se requiere activar y no está activo, activarlo
    if [ "$SHOULD_ACTIVATE" = "true" ] && ! wp --path="$WP_PATH" plugin is-active "$slug" >/dev/null 2>&1; then
      echo "   • Activando plugin existente..."
      if ! wp --path="$WP_PATH" plugin activate "$slug"; then
        echo "   ⚠️  No se pudo activar '$slug' (continuando)."
      fi
    fi
    continue
  fi

  INSTALL_ARGS=("--path=$WP_PATH")
  if [ "$UPDATE_EXISTING" = "true" ]; then
    INSTALL_ARGS+=("--force")
  fi
  if [ "$SHOULD_ACTIVATE" = "true" ]; then
    INSTALL_ARGS+=("--activate")
  fi

  echo "   • Instalando... (args: ${INSTALL_ARGS[*]})"
  if ! wp plugin install "$slug" "${INSTALL_ARGS[@]}"; then
    echo "   ❌ Error instalando '$slug' (continuando con el siguiente)."
    continue
  fi

  # Asegura activación si no se pasó --activate por algún motivo
  if [ "$SHOULD_ACTIVATE" = "true" ] && ! wp --path="$WP_PATH" plugin is-active "$slug" >/dev/null 2>&1; then
    echo "   • Activando..."
    if ! wp --path="$WP_PATH" plugin activate "$slug"; then
      echo "   ⚠️  No se pudo activar '$slug' tras instalación."
    fi
  fi

  echo "   ✅ Listo: $slug"
done

echo "🎉 Proceso de instalación de plugins completado."
