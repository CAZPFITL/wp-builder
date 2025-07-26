<?php
/**
 * Autoload classes for the theme.
 */
function theme_autoload_classes() {
    $base_dir = TEMPLATE_DIR . '/classes/'; // Ruta a la carpeta 'classes'

    $files = array(
        'Traits/Singleton.php',
        'Traits/Fields.php',
        'Traits/Entity.php',

        'Base/Base.php',

        'Admin/Admin.php',
        'Admin/Enqueue.php',

        'PostTypes/Inmueble.php',

        'Taxonomies/Ciudades.php',
        'Taxonomies/Caracteristicas.php',
        'Taxonomies/Estados.php',
        'Taxonomies/Tratos.php',
        'Taxonomies/Tipos.php',
    );

    foreach ($files as $file) {
        $path = $base_dir . $file;

        if (file_exists($path)) {
            require_once $path;
        } else {
            error_log("El archivo $path no se encontró.");
        }
    }
}

theme_autoload_classes();