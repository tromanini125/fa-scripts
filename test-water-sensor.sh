#!/bin/bash

# Script de teste da integração do sensor de água

echo "🧪 Testando integração do sensor de água..."
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurações
DATA_CONSUMER_URL="${DATA_CONSUMER_URL:-http://localhost:8086}"
BFF_URL="${BFF_URL:-http://localhost:3000}"
JWT_TOKEN="${JWT_TOKEN:-}"

# Função de teste
test_endpoint() {
    local name=$1
    local url=$2
    local requires_auth=$3
    
    echo -n "Testando $name... "
    
    if [ "$requires_auth" = "true" ] && [ -z "$JWT_TOKEN" ]; then
        echo -e "${YELLOW}SKIPPED${NC} (JWT_TOKEN não fornecido)"
        return
    fi
    
    if [ "$requires_auth" = "true" ]; then
        response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $JWT_TOKEN" "$url" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ OK${NC}"
        if [ -n "$body" ]; then
            echo "  Response: $(echo "$body" | jq -c '.' 2>/dev/null || echo "$body")"
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (HTTP $http_code)"
        if [ -n "$body" ]; then
            echo "  Error: $body"
        fi
    fi
    echo ""
}

# Testes
echo "================================================"
echo "📡 Testando fa-data-consumer ($DATA_CONSUMER_URL)"
echo "================================================"
echo ""

test_endpoint "Health Check" "$DATA_CONSUMER_URL/health" false
test_endpoint "Latest Sensor Data" "$DATA_CONSUMER_URL/api/water-sensor/latest" true
test_endpoint "Sensor History" "$DATA_CONSUMER_URL/api/water-sensor/history?limit=5" true

echo ""
echo "================================================"
echo "🔄 Testando fa-admin-bff ($BFF_URL)"
echo "================================================"
echo ""

test_endpoint "Water Tank Data" "$BFF_URL/api/dashboard/water-tank" true
test_endpoint "Full Dashboard" "$BFF_URL/api/dashboard" true

echo ""
echo "================================================"
echo "📊 Resumo"
echo "================================================"
echo ""

if [ -z "$JWT_TOKEN" ]; then
    echo -e "${YELLOW}⚠ Aviso:${NC} JWT_TOKEN não fornecido. Para testar endpoints protegidos, defina:"
    echo "  export JWT_TOKEN='seu-token-aqui'"
    echo ""
fi

echo "Para obter um token JWT, faça login:"
echo "  curl -X POST $BFF_URL/api/auth/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"seu@email.com\",\"password\":\"senha\"}'"
echo ""

echo "Para monitorar logs do sensor:"
echo "  kubectl logs -f deployment/fa-data-consumer"
echo ""

echo "Para testar MQTT manualmente:"
echo "  mosquitto_sub -h MQTT_BROKER -p 1883 -u ard_wfs -P PASSWORD -t '#'"
echo ""
