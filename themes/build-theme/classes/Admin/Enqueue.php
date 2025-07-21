<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Enqueue extends Base
{
    use Singleton;

    public function register_actions(): void {
        $this->add_action('admin_enqueue_scripts', 'enqueue_admin_scripts', 1);
//        $this->add_action('admin_enqueue_scripts', 'enqueue_admin_styles', 1);
        $this->add_action('wp_enqueue_scripts', 'enqueue_front_scripts', 1);
//        $this->add_action('wp_enqueue_scripts', 'enqueue_front_styles', 1);
    }

    public function enqueue_admin_scripts() {
        wp_enqueue_script(
            'admin-script-js',
//            TEMPLATE_DIR_URI . '/assets/dist/scripts/admin.js',
	        'http://localhost:5173/scripts/admin.js',
            array(),
            null,
            true
        );

	    add_filter('script_loader_tag', function($tag, $handle) {
		    if ('admin-script-js' === $handle) {
			    $tag = str_replace('<script', '<script type="module"', $tag);
		    }
		    return $tag;
	    }, 10, 2);
    }

    public function enqueue_admin_styles() {
	    wp_enqueue_style(
		    'admin-style-css',
		    // TEMPLATE_DIR_URI . '/assets/dist/styles/admin.css',
		    'http://localhost:5173/scripts/admin.scss',
		    array(),
		    null
	    );
    }

    public function enqueue_front_scripts() {
	    wp_enqueue_script(
		    'front-script-js',
//		    TEMPLATE_DIR_URI . '/assets/dist/scripts/front.js',
		    'http://localhost:5173/scripts/front.js',
		    array(),
		    null,
		    true
	    );

	    add_filter('script_loader_tag', function($tag, $handle) {
		    if ('front-script-js' === $handle) {
			    $tag = str_replace('<script', '<script type="module"', $tag);
		    }
		    return $tag;
	    }, 10, 2);
    }

    public function enqueue_front_styles() {
	    wp_enqueue_style(
		    'front-style-css',
		    // TEMPLATE_DIR_URI . '/assets/dist/styles/front.css',
		    'http://localhost:5173/styles/front.scss',
		    array(),
		    null
	    );
    }
}
