<?php

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

trait Entity
{
    // Stores an array of input configurations for rendering meta fields.
    protected array $inputs = [];

    // Holds the slug identifier for the custom post type or taxonomy.
    protected string $slug = '';

    // Optionally stores custom labels, typically for localization purposes.
    protected mixed $custom_labels = null;

    // Stores basic label information, with 'singular' and 'plural' keys for the entity name.
    protected array $labels = ['singular' => '', 'plural' => ''];

    // Defines the context(s) for which the taxonomy will be registered, such as post types.
    protected array $context = [];

    /**
     * Generates the labels for the custom post type or taxonomy.
     *
     * @param array $labels Array with 'singular' and 'plural' keys for the entity's names.
     *
     * @return array The generated labels, adapted for display in various areas of the admin UI.
     * @throws InvalidArgumentException If required keys are missing or if the input format is invalid.
     */
    public function get_labels(): array {
        // Check if necessary keys exist
        if (!isset($this->labels['singular']) || !isset($this->labels['plural'])) {
            throw new InvalidArgumentException('Required keys "singular" and "plural" are missing.');
        }

        // Extract labels for easier access
        $singular_label = $this->labels['singular'];
        $plural_label = $this->labels['plural'];

        return [
            'name'                     => _x($plural_label, 'Post type general name'),
            'singular_name'            => _x($singular_label, 'Post type singular name'),
            'menu_name'                => _x($plural_label, 'Admin Menu text'),
            'name_admin_bar'           => _x($singular_label, 'Add New on Toolbar'),
            'add_new'                  => __('Add New'),
            'add_new_item'             => __("Add New {$singular_label}"),
            'edit_item'                => __("Edit {$singular_label}"),
            'new_item'                 => __("New {$singular_label}"),
            'view_item'                => __("View {$singular_label}"),
            'view_items'               => __("View {$plural_label}"),
            'search_items'             => __("Search {$plural_label}"),
            'not_found'                => __("No {$plural_label} found"),
            'not_found_in_trash'       => __("No {$plural_label} found in Trash"),
            'parent_item_colon'        => __("Parent {$singular_label}:"),
            'all_items'                => __("All {$plural_label}"),
            'archives'                 => __("{$singular_label} Archives"),
            'attributes'               => __("{$singular_label} Attributes"),
            'insert_into_item'         => __("Insert into {$singular_label}"),
            'uploaded_to_this_item'    => __("Uploaded to this {$singular_label}"),
            'featured_image'           => __('Featured Image'),
            'set_featured_image'       => __('Set featured image'),
            'remove_featured_image'    => __('Remove featured image'),
            'use_featured_image'       => __('Use as featured image'),
            'filter_items_list'        => __("Filter {$plural_label} list"),
            'filter_by_date'           => __('Filter by date'),
            'items_list_navigation'    => __("{$plural_label} list navigation"),
            'items_list'               => __("{$plural_label} list"),
            'item_published'           => __("{$singular_label} published"),
            'item_published_privately' => __("{$singular_label} published privately"),
            'item_reverted_to_draft'   => __("{$singular_label} reverted to draft"),
            'item_scheduled'           => __("{$singular_label} scheduled"),
            'item_updated'             => __("{$singular_label} updated"),
            'item_link'                => __("{$singular_label} link"),
            'item_link_description'    => __("{$singular_label} link description"),
        ];
    }

    /**
     * Loads Spanish labels for the custom post type or taxonomy.
     *
     * Sets the custom_labels property with the Spanish translations of each label string,
     * using the existing 'singular' and 'plural' names for the entity.
     */
    public function load_spanish_labels(): void {
        $singular_label = $this->labels['singular'];
        $plural_label = $this->labels['plural'];

        $this->custom_labels = [
            'name'                     => $plural_label,
            'singular_name'            => $singular_label,
            'menu_name'                => $plural_label,
            'name_admin_bar'           => $singular_label,
            'add_new'                  => 'Añadir nuevo',
            'add_new_item'             => "Añadir {$singular_label}",
            'edit_item'                => "Editar {$singular_label}",
            'new_item'                 => "Nuevo {$singular_label}",
            'view_item'                => "Ver {$singular_label}",
            'view_items'               => "Ver {$plural_label}",
            'search_items'             => "Buscar {$plural_label}",
            'not_found'                => "No se encontraron {$plural_label}",
            'not_found_in_trash'       => "No se encontraron {$plural_label} en la papelera",
            'parent_item_colon'        => "{$singular_label} padre:",
            'all_items'                => "Todos los {$plural_label}",
            'archives'                 => "Archivos de {$singular_label}",
            'attributes'               => "Atributos de {$singular_label}",
            'insert_into_item'         => "Insertar en {$singular_label}",
            'uploaded_to_this_item'    => "Subido a este {$singular_label}",
            'featured_image'           => 'Imagen destacada',
            'set_featured_image'       => 'Establecer imagen destacada',
            'remove_featured_image'    => 'Eliminar imagen destacada',
            'use_featured_image'       => 'Usar como imagen destacada',
            'filter_items_list'        => "Filtrar lista de {$plural_label}",
            'filter_by_date'           => 'Filtrar por fecha',
            'items_list_navigation'    => "Navegación de la lista de {$plural_label}",
            'items_list'               => "Lista de {$plural_label}",
            'item_published'           => "{$singular_label} publicado",
            'item_published_privately' => "{$singular_label} publicado de forma privada",
            'item_reverted_to_draft'   => "{$singular_label} revertido a borrador",
            'item_scheduled'           => "{$singular_label} programado",
            'item_updated'             => "{$singular_label} actualizado",
            'item_link'                => "Enlace de {$singular_label}",
            'item_link_description'    => "Descripción del enlace de {$singular_label}",
        ];
    }


    /**
     * Conditionally loads Spanish labels if the site's locale is set to Spanish.
     *
     * Checks if the locale starts with 'es_' (for any Spanish variant) and, if true, calls
     * load_spanish_labels to set the labels for Spanish localization.
     */
    public function conditionally_load_spanish_labels(): void {
        $locale = get_locale();

        if (strpos($locale, 'es_') === 0) {
            $this->load_spanish_labels();
        }
    }

    /**
     * Registers a custom post type with the generated labels and additional settings.
     *
     * Retrieves the labels from get_labels and, if custom labels are available,
     * merges them into the registration arguments for the post type. Then calls
     * register_post_type to register the custom post type with WordPress.
     */
    public function register_post_type(): void {
        $labels = $this->get_labels();

        $args = array_merge($this->args, [
            'labels' => is_array($this->custom_labels) ? $this->custom_labels : $labels,
            'rewrite' => ['slug' => $this->slug]
        ]);

        register_post_type($this->slug, $args);
    }

    /**
     * Registers a taxonomy with the generated labels and additional settings.
     *
     * Retrieves labels from get_labels and, if custom labels are available,
     * merges them into the registration arguments for the taxonomy. Then calls
     * register_taxonomy to register the taxonomy with WordPress.
     */
    public function register_taxonomy(): void {
        $labels = $this->get_labels();

        $args = array_merge($this->args, ['labels' => is_array($this->custom_labels) ? $this->custom_labels : $labels]);

        register_taxonomy($this->slug, $this->context, $args);
    }
}