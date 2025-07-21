<?php

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

class Caracteristicas extends Base {
	use Singleton;

	protected string $slug = 'caracteristica';

	protected array $labels = [ 'singular' => 'Caracteristica', 'plural' => 'Caracteristicas' ];

	protected array $context = [ 'inmueble' ];

	protected array $add_meta_boxes = [
		[
			'wrap'  => true,
			'name'  => 'color',
			'label' => 'color',
			'type'  => 'color'
		]
	];

	protected array $edit_meta_boxes = [
		[
			'wrap'  => true,
			'name'  => 'color',
			'label' => 'color',
			'type'  => 'color'
		]
	];

	protected array $args = [
		'public'            => true, // Hacer la taxonomía accesible públicamente
		'rewrite'           => [ 'slug' => 'caracteristica' ], // Slug para la URL
		'hierarchical'      => true, // Comportamiento jerárquico como categorías
		'show_ui'           => true, // Mostrar en el administrador
		'show_in_menu'      => true, // Mostrar en el menú del administrador
		'show_admin_column' => true, // Mostrar columna en la lista de posts
		'query_var'         => true, // Permitir query var para la taxonomía
		'show_in_rest'      => true, // Hacer que funcione con Gutenberg y la REST API
	];

	// Taxonomies uses 20 to 30 as priority
	public function register_actions(): void {
		$this->add_action( 'init', 'conditionally_load_spanish_labels', 10 );
		$this->add_action( 'init', 'register_taxonomy', 20 );
		$this->add_action( 'init', 'load_fields', 20 );
	}
}