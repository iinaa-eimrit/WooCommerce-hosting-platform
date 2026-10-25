#!/bin/sh
set -eu
cd /var/www/html
until [ -f wp-config.php ]; do sleep 5; done
until wp db query 'SELECT 1' >/dev/null 2>&1; do sleep 5; done
if ! wp core is-installed 2>/dev/null; then
  admin_password_flag=--admin_password
  wp core install --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$WP_ADMIN_USER" "$admin_password_flag=$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email
fi
wp option delete core_updater.lock || true
wp core update --version="$WP_CORE_VERSION" --force
wp core update-db
wp option update timezone_string UTC
wp rewrite structure '/%postname%/' --hard || true
wp plugin is-installed woocommerce || wp plugin install woocommerce
wp plugin activate woocommerce
wp theme is-installed storefront || wp theme install storefront
wp theme activate storefront
wp wc tool run install_pages --user="$WP_ADMIN_USER" || true
wp option update woocommerce_coming_soon no
wp option update woocommerce_cod_settings '{"enabled":"yes","title":"Cash on delivery","description":"Pay with cash upon delivery.","instructions":"","enable_for_methods":[],"enable_for_virtual":"yes"}' --format=json
if ! wp user get mcp-bot >/dev/null 2>&1; then wp user create mcp-bot mcp-bot@store.local --role=shop_manager --user_pass="$(head -c 32 /dev/urandom | base64)"; fi
if [ "$(wp post list --post_type=product --format=count)" = 0 ]; then wp wc product create --user="$WP_ADMIN_USER" --name='Urumi Hoodie' --regular_price=1499 --status=publish; fi
echo 'Store setup complete.'
