#!/bin/bash
# Test script for provider switching functionality
# Tests both TBO and Hotelbeds providers through /tcm/v1/hotels-search

set -e

echo "🧪 TCM Multi-Provider Testing Suite"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get WordPress container name
WP_CONTAINER=$(docker-compose ps -q wordpress 2>/dev/null || echo "")

if [ -z "$WP_CONTAINER" ]; then
    echo -e "${RED}❌ WordPress container not running${NC}"
    echo "Start the stack with: docker-compose up -d"
    exit 1
fi

echo "✅ WordPress container detected: $WP_CONTAINER"
echo ""

# Function to restart WordPress to reload .env
restart_wordpress() {
    echo -e "${YELLOW}🔄 Restarting WordPress to reload .env...${NC}"
    docker-compose restart wordpress
    sleep 3
    echo -e "${GREEN}✅ WordPress restarted${NC}"
    echo ""
}

# Function to test endpoint
test_endpoint() {
    local provider=$1
    echo -e "${YELLOW}Testing provider: $provider${NC}"
    
    # Get WordPress URL
    WP_URL="http://localhost:8080"
    
    # Test payload (canonical format)
    PAYLOAD='{
        "checkIn": "2026-03-15",
        "checkOut": "2026-03-18",
        "nationality": "MX",
        "cityCode": "CUN",
        "paxRooms": [
            {
                "adults": 2,
                "children": 0,
                "childrenAges": []
            }
        ],
        "page": 1,
        "perPage": 5
    }'
    
    echo "📡 Calling: POST $WP_URL/wp-json/tcm/v1/hotels-search"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        "$WP_URL/wp-json/tcm/v1/hotels-search" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ HTTP 200 OK${NC}"
        
        # Check if response contains provider field
        RESPONSE_PROVIDER=$(echo "$BODY" | jq -r '.provider // empty' 2>/dev/null || echo "")
        
        if [ -n "$RESPONSE_PROVIDER" ]; then
            echo -e "${GREEN}✅ Provider in response: $RESPONSE_PROVIDER${NC}"
        fi
        
        # Count hotels
        HOTEL_COUNT=$(echo "$BODY" | jq '.data.hotels | length' 2>/dev/null || echo "0")
        echo -e "${GREEN}✅ Hotels found: $HOTEL_COUNT${NC}"
        
        # Show first hotel name if available
        FIRST_HOTEL=$(echo "$BODY" | jq -r '.data.hotels[0].hotelName // empty' 2>/dev/null || echo "")
        if [ -n "$FIRST_HOTEL" ]; then
            echo -e "${GREEN}✅ First hotel: $FIRST_HOTEL${NC}"
        fi
        
    else
        echo -e "${RED}❌ HTTP $HTTP_CODE${NC}"
        echo "Response: $BODY" | jq '.' 2>/dev/null || echo "$BODY"
    fi
    
    echo ""
}

# Test 1: TBO Provider
echo "================================================"
echo "TEST 1: TBO Provider (default)"
echo "================================================"

# Ensure .env has TBO
sed -i 's/^TCM_FORCE_PROVIDER=.*/TCM_FORCE_PROVIDER=tbo/' .env

restart_wordpress
test_endpoint "tbo"

# Test 2: Hotelbeds Provider
echo "================================================"
echo "TEST 2: Hotelbeds Provider"
echo "================================================"

# Change .env to Hotelbeds
sed -i 's/^TCM_FORCE_PROVIDER=.*/TCM_FORCE_PROVIDER=hotelbeds/' .env

restart_wordpress
test_endpoint "hotelbeds"

# Restore to TBO
echo "================================================"
echo "Cleanup: Restoring TCM_FORCE_PROVIDER=tbo"
echo "================================================"

sed -i 's/^TCM_FORCE_PROVIDER=.*/TCM_FORCE_PROVIDER=tbo/' .env
restart_wordpress

echo ""
echo -e "${GREEN}🎉 Testing complete!${NC}"
echo ""
echo "Summary:"
echo "- Both providers should respond on /tcm/v1/hotels-search"
echo "- Frontend code requires NO changes"
echo "- Canonical format maintained across providers"
