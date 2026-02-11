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

# Test 1: Booking Adapter
echo ""
echo -e "${YELLOW}1. Booking Adapter${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
if docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/unit/test-booking-adapter.php 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# Test 2: Booking Repository
echo ""
echo -e "${YELLOW}2. Booking Repository${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
if docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/unit/test-booking-repository.php 2>&1 | grep -q "ALL TESTS COMPLETED"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

echo ""
echo "========================================="
echo "📋 PRUEBAS DE INTEGRACIÓN"
echo "========================================="

# Test 3: REST Endpoints
echo ""
echo -e "${YELLOW}3. REST Endpoints${NC}"
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

# Test 4: Booking Integration
echo ""
echo -e "${YELLOW}4. Booking Integration${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/integration/test-booking-integration.php 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# Test 5: User Booking Queries
echo ""
echo -e "${YELLOW}5. User Booking Queries${NC}"
echo "---"
TOTAL_TESTS=$((TOTAL_TESTS+1))
docker-compose exec -T wordpress php /var/www/html/wp-content/themes/travel-concierge-me-theme/tests/integration/test-user-booking-queries.php 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS+1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS+1))
fi

# Test 6: TBO Booking Flow
echo ""
echo -e "${YELLOW}6. TBO Booking Flow (puede tardar ~30s)${NC}"
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

# Test 7: TBO Booking with Cancel
echo ""
echo -e "${YELLOW}7. TBO Booking with Cancellation (puede tardar ~45s)${NC}"
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
