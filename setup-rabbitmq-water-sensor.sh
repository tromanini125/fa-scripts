#!/bin/bash

# Script para configurar RabbitMQ para replicar MQTT para AMQP

echo "🐰 Configurando RabbitMQ para Water Sensor..."
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configurações
RABBITMQ_HOST="${RABBITMQ_HOST:-localhost}"
RABBITMQ_PORT="${RABBITMQ_PORT:-15672}"
RABBITMQ_USER="${RABBITMQ_USER:-tromanini}"
RABBITMQ_PASS="${RABBITMQ_PASS:-tem230112}"
QUEUE_NAME="water-sensor-data"

echo "📋 Configurações:"
echo "  Host: $RABBITMQ_HOST:$RABBITMQ_PORT"
echo "  User: $RABBITMQ_USER"
echo "  Queue: $QUEUE_NAME"
echo ""

# Função para fazer requisições
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
         -X "$method" \
         -H 'Content-Type: application/json' \
         "http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/$endpoint" \
         ${data:+-d "$data"}
}

# 1. Criar a fila
echo -n "📦 Criando fila $QUEUE_NAME... "
response=$(make_request PUT "queues/%2F/$QUEUE_NAME" '{
  "durable": true,
  "auto_delete": false,
  "arguments": {}
}')

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "Erro: $response"
fi

# 2. Criar bindings para os 3 tópicos MQTT
topics=("water-level" "water-flux" "pump-status")

for topic in "${topics[@]}"; do
    echo -n "🔗 Criando binding para $topic... "
    
    response=$(make_request POST "bindings/%2F/e/amq.topic/q/$QUEUE_NAME" "{
      \"routing_key\": \"$topic\",
      \"arguments\": {}
    }")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo "Erro: $response"
    fi
done

echo ""
echo "================================================"
echo "✅ Configuração concluída!"
echo "================================================"
echo ""
echo "Próximos passos:"
echo ""
echo "1. Verificar se o sensor está publicando mensagens MQTT:"
echo "   mosquitto_sub -h $RABBITMQ_HOST -p 1883 -u ard_wfs -P chItD9ZTWYSHqmrr -t '#' -v"
echo ""
echo "2. Verificar mensagens na fila:"
echo "   curl -u $RABBITMQ_USER:$RABBITMQ_PASS http://$RABBITMQ_HOST:$RABBITMQ_PORT/api/queues/%2F/$QUEUE_NAME"
echo ""
echo "3. Consumir mensagens manualmente (teste):"
echo "   amqp-consume -s $RABBITMQ_HOST -q $QUEUE_NAME cat"
echo ""
echo "4. Iniciar o fa-data-consumer:"
echo "   ./bin/fa-data-consumer"
echo ""
echo "Management UI: http://$RABBITMQ_HOST:$RABBITMQ_PORT"
echo ""
