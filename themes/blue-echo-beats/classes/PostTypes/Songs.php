<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Songs extends Base
{
    use Singleton;

    protected string $slug = 'songs';

    protected array $labels = ['singular' => 'Song', 'plural' => 'Songs'];

    protected mixed $custom_labels = 1;

    protected array $args = [
        'public'       => true,
        'has_archive'  => true,
        'rewrite'      => ['slug' => 'songs'],
        'supports'     => ['title', 'editor', 'thumbnail', 'custom-fields'],
        'show_ui'      => true,
        'show_in_menu' => true,
        'show_in_rest' => true,
    ];

    public function register_actions(): void {
        $this->add_action('init', 'conditionally_load_spanish_labels', 10);
        $this->add_action('init', 'register_post_type', 10);
    }
}