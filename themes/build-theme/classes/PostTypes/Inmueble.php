<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Inmueble extends Base
{
    use Singleton;

    protected string $slug = 'inmueble';

    protected array $labels = ['singular' => 'Inmueble', 'plural' => 'Inmuebles'];

    protected mixed $custom_labels = 1;

    protected array $args = [
        'public'       => true,
        'has_archive'  => true,
        'rewrite'      => ['slug' => 'inmuebles'],
        'supports'     => ['title', 'editor', 'thumbnail', 'custom-fields'],
        'show_ui'      => true,
        'show_in_menu' => true,
        'show_in_rest' => true, // Para habilitar el editor de bloques y la API REST.
    ];

    // Post Types uses 10 to 20 as priority
    public function register_actions(): void {
        $this->add_action('init', 'conditionally_load_spanish_labels', 10);
        $this->add_action('init', 'register_post_type', 10);
    }
}