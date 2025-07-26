<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

class Base
{
    use Entity;
    use Fields;
    use Singleton;

    public function __construct()
    {
        $this->init();
    }

    public function init(): void
    {
        // Load filters and actions
        $this->register_actions();
        $this->register_filters();
    }

    public function register_actions(): void
    {
    }

    public function register_filters(): void
    {
    }

    /*
     * Add actions
     */
    public function add_action($hook, $callback, $priority = 10, $accepted_args = 1): void
    {
        add_action($hook, [$this, $callback], $priority, $accepted_args);
    }

    /*
     * Add filters
     */
    public function add_filter($hook, $callback, $priority = 10, $accepted_args = 1): void
    {
        add_filter($hook, [$this, $callback], $priority, $accepted_args);
    }
}
