<?php

if (!defined('ABSPATH')) {
    exit;
}

class Enqueue extends Base
{
    use Singleton;

    private $is_dev;
    private $vite_url;

    public function __construct()
    {
        $this->is_dev = getenv('VITE_DEV_MODE'); // Lee tu variable de entorno
        $this->vite_url = 'http://localhost:' . getenv('VITE_PORT'); // Puerto de Vite dev
        parent::__construct();
    }

    public function register_actions(): void
    {
        $this->add_action('admin_enqueue_scripts', 'enqueue_admin_scripts', 1);
        $this->add_action('admin_enqueue_scripts', 'enqueue_admin_styles', 1);
        $this->add_action('wp_enqueue_scripts', 'enqueue_front_scripts', 1);
        $this->add_action('wp_enqueue_scripts', 'enqueue_front_styles', 1);
    }

    public function enqueue_admin_scripts()
    {
        $src = $this->is_dev
            ? $this->vite_url . '/scripts/admin.js'
            : TEMPLATE_DIR_URI . '/assets/dist/scripts/admin.js';

        wp_enqueue_script('admin-script-js', $src, array(), null, true);

        add_filter('script_loader_tag', function ($tag, $handle) {
            if ('admin-script-js' === $handle) {
                $tag = str_replace('<script', '<script type="module"', $tag);
            }
            return $tag;
        }, 10, 2);
    }

    public function enqueue_admin_styles()
    {
        $src = $this->is_dev
            ? $this->vite_url . '/styles/admin.scss'
            : TEMPLATE_DIR_URI . '/assets/dist/styles/admin.css';

        wp_enqueue_style('admin-style-css', $src, array(), null);
    }

    public function enqueue_front_scripts()
    {
        $src = $this->is_dev
            ? $this->vite_url . '/scripts/front.js'
            : TEMPLATE_DIR_URI . '/assets/dist/scripts/front.js';

        wp_enqueue_script('front-script-js', $src, array(), null, true);

        add_filter('script_loader_tag', function ($tag, $handle) {
            if ('front-script-js' === $handle) {
                $tag = str_replace('<script', '<script type="module"', $tag);
            }
            return $tag;
        }, 10, 2);
    }

    public function enqueue_front_styles()
    {
        $src = $this->is_dev
            ? $this->vite_url . '/styles/front.scss'
            : TEMPLATE_DIR_URI . '/assets/dist/styles/front.css';

        wp_enqueue_style('front-style-css', $src, array(), null);
    }
}
