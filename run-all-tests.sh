#!/bin/bash

# Travel Concierge Me - Test Suite Runner
# Ejecuta todas las pruebas unitarias e integración

echo "========================================="
echo "TRAVEL CONCIERGE ME - TEST SUITE"
echo "========================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contador de resultados
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "📋 PRUEBAS UNITARIAS"
echo "========================================="

# Helper: run an offline unit test by relative path; pass if exit code 0
run_offline_test() {
    local label="$1"
    local rel_path="$2"
    echo ""
    echo -e "${YELLOW}${label}${NC}"
    echo "---"
    TOTAL_TESTS=$((TOTAL_TESTS+1))
    docker-compose exec -T wordpress php "/var/www/html/wp-content/themes/travel-concierge-me-theme/tests/${rel_path}" 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS+1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS+1))
    fi
}

# Test 1: Booking Repository (V2 schema invariants — passes when no assertions failed)
echo ""
echo -e "${YELLOW}1. Booking Repository${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
# V2 test prints "Results: N/N passed" — we pass only when failed-count is 0.
_repo_out=$(docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/unit/test-booking-repository.php 2>&1)
echo "$_repo_out"
if echo "$_repo_out" | grep -Eq "Results: ([0-9]+)/\1 passed"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# NOTE: 1b. TBO Booking Adapter removed — `tests/unit/test-booking-adapter.php`
# and the `TboBookingAdapter` class were deleted in the multi-provider DB redesign
# (PR #68 / 2026-04-21). Persistence is now exercised by test-booking-repository.php
# (V2 invariants) + integration tests #3 and #4 (real TBO flow).

# Test 1c: Card-Safe Validator (Contract V1)
run_offline_test "1c. Card-Safe Validator (Contract V1)" "unit/test-card-safe-validator.php"

# Test 1d: Contract Enforcement (enforce_batch + booking guard)
run_offline_test "1d. Contract Enforcement" "unit/test-contract-enforcement.php"

# NOTE: unit/test-contract-refresh.php is state-dependent (WP-Cron rate-limit
# locks + transients persist across runs). Run it in isolation against a clean
# environment instead of including it here:
#   docker compose exec wordpress php .../tests/unit/test-contract-refresh.php

# Test 1f: L2 Cache Rules (TTL policy)
run_offline_test "1f. L2 Cache Rules (TTL)" "unit/test-l2-cache-rules.php"

echo ""
echo "========================================="
echo "📋 PRUEBAS DE INTEGRACIÓN"
echo "========================================="

# Test 2: REST Endpoints
echo ""
echo -e "${YELLOW}2. REST Endpoints${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/integration/test-rest-endpoints.php 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# Test 3: TBO Booking Flow
echo ""
echo -e "${YELLOW}3. TBO Booking Flow (puede tardar ~30s)${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/integration/tbo-booking-flow-test.php 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# Test 4: TBO Booking with Cancel
echo ""
echo -e "${YELLOW}4. TBO Booking with Cancellation (puede tardar ~45s)${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/integration/tbo-booking-with-cancel-test.php 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# ---------------------------------------------------------------------------
# OPTIONAL: Network-dependent tests (TBO/Hotelbeds live API).
# Enable with: RUN_NETWORK_TESTS=1 ./run-all-tests.sh
# These hit external provider APIs and may be slow / non-deterministic.
# ---------------------------------------------------------------------------
if [ "${RUN_NETWORK_TESTS:-0}" = "1" ]; then
    echo ""
    echo "========================================="
    echo "🌐 PRUEBAS DE RED (provider APIs)"
    echo "========================================="

    run_offline_test "5. Contract Enforcement Manual (UnifiedHotelEndpoint live)" \
        "unit/test-contract-enforcement-manual.php"
    run_offline_test "6. Contract Enforcement Simulated (TBO + simulación)" \
        "unit/test-contract-enforcement-simulated.php"
    run_offline_test "7. Stale L1 Manual (TBO live)" \
        "unit/test-stale-l1-manual.php"
    run_offline_test "8. Destinations Endpoint" \
        "integration/test-destinations-endpoint.php"
    run_offline_test "9. GeonameId Resolution (TBO countries)" \
        "integration/test-geoname-resolution.php"
    run_offline_test "10. Provider Search (TBO live)" \
        "integration/test-provider-search.php"
    run_offline_test "11. Resolution-Only (TBO countries)" \
        "integration/test-resolution-only.php"
else
    echo ""
    echo -e "${YELLOW}ℹ️  Pruebas de red omitidas (set RUN_NETWORK_TESTS=1 para incluirlas)${NC}"
fi

# Resumen final
echo ""
echo "========================================="
echo "📊 RESUMEN DE PRUEBAS"
echo "========================================="
echo "Total de pruebas: $TOTAL_TESTS"
echo -e "${GREEN}Exitosas: $PASSED_TESTS${NC}"
echo -e "${RED}Fallidas: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ TODAS LAS PRUEBAS PASARON${NC}"
    exit 0
else
    echo -e "${RED}✗ ALGUNAS PRUEBAS FALLARON${NC}"
    exit 1
fi
