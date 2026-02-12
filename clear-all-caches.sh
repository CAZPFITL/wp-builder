#!/bin/bash
# Clear ALL caches - Use before production deployment
# Ensures fresh data and no cache corruption

set -e

echo "🧹 Clearing ALL caches..."
echo ""

echo "1️⃣ Flushing WordPress object cache..."
docker compose exec wordpress wp cache flush

echo ""
echo "2️⃣ Deleting ALL transients (L1 cache - provider raw data)..."
docker compose exec wordpress wp transient delete --all

echo ""
echo "3️⃣ Deleting L2 canonical cache (transformed hotel data)..."
docker compose exec wordpress wp eval '
global $wpdb;
$deleted = 0;
do {
    $batch = $wpdb->query("DELETE FROM {$wpdb->options} WHERE option_name LIKE \"canonical_hotel_v1_%\" LIMIT 10000");
    $deleted += $batch;
} while ($batch === 10000);
echo "Deleted: " . $deleted . " canonical cache entries\n";
'

echo ""
echo "4️⃣ Deleting provider-specific transients..."
docker compose exec wordpress wp eval '
global $wpdb;
$patterns = [
    "hotelbeds_content_%",
    "hotelbeds_countries_%", 
    "hotelbeds_destinations_%",
    "tbo_hotel_detail_%",
    "tbo_countries_%",
    "tbo_cities_%"
];
$total = 0;
foreach ($patterns as $pattern) {
    $deleted = $wpdb->query($wpdb->prepare(
        "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s",
        $pattern
    ));
    echo "Deleted " . $deleted . " entries matching: " . $pattern . "\n";
    $total += $deleted;
}
echo "\nTotal provider cache deleted: " . $total . "\n";
'

echo ""
echo "5️⃣ Deleting old canonical cache versions (cleanup)..."
docker compose exec wordpress wp eval '
global $wpdb;
$deleted = $wpdb->query("DELETE FROM {$wpdb->options} WHERE option_name LIKE \"canonical_hotel_v0_%\"");
echo "Deleted: " . $deleted . " old version cache entries\n";
'

echo ""
echo "✅ ALL CACHES CLEARED SUCCESSFULLY!"
echo ""
echo "📊 Cache Summary:"
docker compose exec wordpress wp eval '
global $wpdb;
$transients = $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->options} WHERE option_name LIKE \"_transient_%\"");
$canonical = $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->options} WHERE option_name LIKE \"canonical_hotel_v1_%\"");
echo "  • Remaining transients: " . $transients . "\n";
echo "  • Remaining L2 cache: " . $canonical . "\n";
'

echo ""
echo "🚀 System ready for production deployment!"
