<?php

$img = 'home_hero.png';

if (is_single()) {
	// Obtiene la imagen destacada del post
	$post_thumbnail = get_the_post_thumbnail_url(get_the_ID(), 'full');
	if ($post_thumbnail) {
		$background_image = esc_url($post_thumbnail);
	}
} elseif (is_archive()) {
	$img = 'archive_01.png';
} elseif (is_tax('trato', 'venta')) {
	$img = 'archive_02.png';
}

// Configura la imagen de fondo
if (!isset($background_image)) {
	$background_image = esc_url(TEMPLATE_DIR_URI . '/assets/public/images/' . $img);
}

$style = "background-image: url('$background_image');";
?>

<div class="hero">
    <div class="image" style="<?php echo $style; ?>"></div>
</div>
