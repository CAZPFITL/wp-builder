<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Admin extends Base
{
    use Singleton;

    public function load_instances(): void {
        Enqueue::getInstance();

        Inmueble::getInstance();

        Caracteristicas::getInstance();
        Ciudades::getInstance();
        Estados::getInstance();
        Tipos::getInstance();
        Tratos::getInstance();
    }

    // Admin uses 0 to 10 as priority
    public function register_actions(): void {
        $this->add_action('after_setup_theme', 'load_instances', 0);
        $this->add_action('admin_menu', 'remove_menus', 1);
	    $this->add_action('after_setup_theme', 'boilerplate_setup');
    }

	public function boilerplate_setup() {
		add_theme_support('post-thumbnails');
	}

    public function remove_menus(): void {
        remove_menu_page('edit.php');
    }
}
