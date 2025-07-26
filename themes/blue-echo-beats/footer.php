<?php
/**
 * Template for displaying the footer
 *
 * @package blue-echo-beats
 */
?>
<canvas id="starfield"></canvas>
<footer class="beb-footer">
    <div class="beb-footer__container">
        <div class="beb-footer__brand">
            <?php if ( has_custom_logo() ) : ?>
                <div class="beb-footer__logo"><?php the_custom_logo(); ?></div>
            <?php endif; ?>
            <div class="beb-footer__text">
                <span class="beb-footer__title"><?php bloginfo('name'); ?></span>
                <span class="beb-footer__tagline"><?php bloginfo('description'); ?></span>
            </div>
        </div>

        <?php
        wp_nav_menu( array(
            'theme_location' => 'footer',
            'container'      => false,
            'menu_class'     => 'beb-footer__list',
            'fallback_cb'    => false,
        ) );
        ?>

        <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?>. All rights reserved.</p>
    </div>
</footer>

<?php wp_footer(); ?>
</body>
</html>
