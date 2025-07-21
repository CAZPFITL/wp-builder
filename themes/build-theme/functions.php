<?php
/**
 * Emede functions and definitions
 *
 * @link https://developer.wordpress.org/themes/basics/theme-functions/
 *
 * @package boilerplate
 */

if ( ! defined( 'BIOLERPLATE_VERSION' ) ) {
    define( 'BIOLERPLATE_VERSION', '1.0.0' );
}

if ( ! defined( 'TEMPLATE_DIR' ) ) {
    define( 'TEMPLATE_DIR', get_template_directory() );
}

if ( ! defined( 'TEMPLATE_DIR_URI' ) ) {
    define( 'TEMPLATE_DIR_URI', get_template_directory_uri() );
}

require_once TEMPLATE_DIR . '/loader.php';

if (class_exists('Admin')) {
    Admin::getInstance();
}
