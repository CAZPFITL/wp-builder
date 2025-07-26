<?php
/**
 * Template part for displaying the main navigation bar
 *
 * @package blue-echo-beats
 */
?>

<nav class="beb-navbar">
    <div class="beb-navbar__container">
        <div class="beb-navbar__logo">
            <?php if ( has_custom_logo() ) : ?>
                <?php the_custom_logo(); ?>
            <?php endif; ?>

            <a href="<?php echo esc_url( home_url( '/' ) ); ?>" class="beb-navbar__title">
                <?php bloginfo( 'name' ); ?>
            </a>
        </div>
        <div class="beb-navbar__menu">
            <?php
            wp_nav_menu( array(
                'theme_location' => 'primary',
                'container'      => false,
                'menu_class'     => 'beb-navbar__list',
                'fallback_cb'    => false,
            ) );
            ?>
        </div>
        <div class="beb-navbar__auth">
            <?php if ( is_user_logged_in() ) : ?>
                <a href="<?php echo esc_url( wp_logout_url() ); ?>" class="beb-navbar__link">Log out</a>
            <?php else : ?>
                <a href="<?php echo esc_url( wp_login_url() ); ?>" class="beb-navbar__link">Log in</a>
            <?php endif; ?>
        </div>
    </div>
</nav>
