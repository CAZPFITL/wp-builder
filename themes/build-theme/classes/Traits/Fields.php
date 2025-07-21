<?php

if (!defined('ABSPATH')) {
    exit;
}

trait Fields
{
    // Stores additional metadata fields for adding new items in the taxonomy or post type.
    protected array $add_meta_boxes = [];

    // Stores additional metadata fields for editing existing items in the taxonomy or post type.
    protected array $edit_meta_boxes = [];

    /**
     * Loads the field actions for adding and editing meta boxes in a taxonomy or post type.
     *
     * @param bool $add  Whether to load actions for adding new items. Default true.
     * @param bool $edit Whether to load actions for editing existing items. Default true.
     */
    public function load_fields()
    {
        $this->add_action("{$this->slug}_add_form_fields", 'print_add_meta_boxes', 20);
        $this->add_action("{$this->slug}_edit_form_fields", 'print_edit_meta_boxes', 20);
        $this->add_action("create_{$this->slug}", 'save_fields', 20);
        $this->add_action("edited_{$this->slug}", 'save_fields', 20);
    }

    /**
     * Displays the add meta boxes when creating a new item in the taxonomy or post type.
     */
    public function print_add_meta_boxes()
    {
        $this->print($this->add_meta_boxes);
    }

    /**
     * Displays the edit meta boxes when editing an existing item in the taxonomy or post type.
     */
    public function print_edit_meta_boxes()
    {
        $this->print($this->edit_meta_boxes);
    }

    /**
     * Outputs the HTML for each field in a given array of input configurations.
     *
     * @param array $array Array of input field configurations to print.
     */
    public function print($array)
    {
        if (isset($_GET['post'])) {
            return;
        }

        $is_editing = isset($_GET['tag_ID']);
        $id = $is_editing ? (int) $_GET['tag_ID'] : null;

        foreach ($array as $input) {
            $value = $is_editing && $id ? (get_term_meta($id, $input['name'], true) ?? $input['value']) : ($input['value'] ?? '');

            echo sprintf(
                '<tr class="form-field">
                <th valign="top" scope="row">
                    <label for="%s">%s</label>
                </th>
                <td>',
                esc_attr($input['name'] . (!empty($input['key']) ? "_{$input['key']}" : '')),
                esc_html($input['label'])
            );

            switch ($input['type']) {
                case 'select':
                    $options_html = '';
                    foreach ($input['options'] as $option_value => $option_label) {
                        $selected = selected($value, $option_value, false);
                        $options_html .= sprintf(
                            '<option value="%s" %s>%s</option>',
                            esc_attr($option_value),
                            $selected,
                            esc_html($option_label)
                        );
                    }
                    echo sprintf(
                        '<select name="%s" style="%s">%s</select>',
                        esc_attr($input['name']),
                        esc_attr($input['style'] ?? ''),
                        $options_html
                    );
                    break;

                case 'text':
                    echo sprintf(
                        '<input type="text" name="%s" style="%s" value="%s" />',
                        esc_attr($input['name']),
                        esc_attr($input['style'] ?? ''),
                        esc_attr($value)
                    );
                    break;

                case 'color':
                    echo sprintf(
                        '<input type="color" autocomplete="off" style="width: 25em" id="%s" name="%s" value="%s" />',
                        esc_attr($input['name'] . (!empty($input['key']) ? "_{$input['key']}" : '')),
                        esc_attr($input['name']),
                        esc_attr($value)
                    );
                    break;
            }

            if (!empty($input['description'])) {
                echo sprintf('<p class="description"><small>%s</small></p>', esc_html($input['description']));
            }
            if (!empty($input['hint'])) {
                echo sprintf('<p class="hint">%s</p>', esc_html($input['hint']));
            }

            echo '</td></tr>';
        }
    }


    /**
     * Saves the metadata fields for taxonomy terms based on the provided ID.
     *
     * @param int $post_id ID of the term for which fields are being saved.
     */
    public function save_fields($post_id)
    {
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }

        if (!current_user_can('edit_term', $post_id)) {
            return;
        }

        $is_editing = isset($_GET['tag_ID']) || did_action("edited_{$this->slug}");
        $meta_boxes = $is_editing ? $this->edit_meta_boxes : $this->add_meta_boxes;

        foreach ($meta_boxes as $input) {
            if (isset($_POST[$input['name']])) {
                update_term_meta($post_id, $input['name'], sanitize_text_field($_POST[$input['name']]));
            }
        }
    }


}
