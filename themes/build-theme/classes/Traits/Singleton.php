<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

trait Singleton {
    /**
     * Static variable to hold the instance of the class using this trait.
     */
    private static $instance;

    /**
     * Static method to get the instance of the class using the Singleton trait.
     *
     * @return static The Singleton instance of the class.
     */
    public static function getInstance() {
        if (!isset(self::$instance)) {
            self::$instance = new static(); // Create new instance if not available
        }
        return self::$instance;
    }
}
