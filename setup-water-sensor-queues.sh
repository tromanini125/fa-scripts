#!/bin/bash

# =============================================================================
# Script para configurar as filas e bindings do RabbitMQ para os sensores de água
# 
# Este script cria:
# - Fila water-level-queue (para dados de nível de água)
# - Fila water-flux-queue (para dados de fluxo de água)
# - Bindings do exchange amq.topic para as filas usando routing keys MQTT
#
# Os tópicos MQTT publicados pelo Arduino são:
# - water-level: dados de nível de água
# - water-flux: dados de fluxo de água
# - pump-status: (ignorado) status da bomba
#
# O plugin MQTT do RabbitMQ publica no exchange amq.topic usando o tópico
# MQTT como routing key.
# =============================================================================

set -e

# Configurações padrão
RABBITMQ_HOST="${RABBITMQ_HOST:-localhost}"
RABBITMQ_PORT="${RABBITMQ_PORT:-15672}"
RABBITMQ_USER="${RABBITMQ_USER:-tromanini}"
RABBITMQ_PASS="${RABBITMQ_PASS:-tem230112}"
RABBITMQ_VHOST="${RABBITMQ_VHOST:-/}"

# Encode vhost para URL (/ -> %2F)
VHOST_ENCODED=$(echo -n "$RABBITMQ_VHOST" | jq -sRr @uri)

BASE_URL="http://${RABBITMQ_HOST}:${RABBITMQ_PORT}/api"

echo "=============================================="
echo "  RabbitMQ Water Sensor Setup"
echo "=============================================="
echo "Host: $RABBITMQ_HOST:$RABBITMQ_PORT"
echo "VHost: $RABBITMQ_VHOST"
echo ""

# Função para fazer requisições HTTP
rabbitmq_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -n "$data" ]; then
        curl -s -X "$method" \
            -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${BASE_URL}${endpoint}"
    else
        curl -s -X "$method" \
            -u "${RABBITMQ_USER}:${RABBITMQ_PASS}" \
            "${BASE_URL}${endpoint}"
    fi
}

# Verifica conexão
echo "🔍 Verificando conexão com RabbitMQ..."
if ! rabbitmq_api GET "/overview" > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao RabbitMQ em $RABBITMQ_HOST:$RABBITMQ_PORT"
    exit 1
fi
echo "✅ Conexão OK"
echo ""

# Cria fila water-level-queue
echo "📦 Criando fila: water-level-queue"
rabbitmq_api PUT "/queues/${VHOST_ENCODED}/water-level-queue" '{
    "durable": true,
    "auto_delete": false,
    "arguments": {}
}'
echo "✅ water-level-queue criada"

# Cria fila water-flux-queue
echo "📦 Criando fila: water-flux-queue"
rabbitmq_api PUT "/queues/${VHOST_ENCODED}/water-flux-queue" '{
    "durable": true,
    "auto_delete": false,
    "arguments": {}
}'
echo "✅ water-flux-queue criada"
echo ""

# Cria binding para water-level
echo "🔗 Criando binding: amq.topic -> water-level-queue (routing key: water-level)"
rabbitmq_api POST "/bindings/${VHOST_ENCODED}/e/amq.topic/q/water-level-queue" '{
    "routing_key": "water-level",
    "arguments": {}
}'
echo "✅ Binding water-level criado"

# Cria binding para water-flux
echo "🔗 Criando binding: amq.topic -> water-flux-queue (routing key: water-flux)"
rabbitmq_api POST "/bindings/${VHOST_ENCODED}/e/amq.topic/q/water-flux-queue" '{
    "routing_key": "water-flux",
    "arguments": {}
}'
echo "✅ Binding water-flux criado"
echo ""

# Lista as filas criadas
echo "📋 Filas configuradas:"
rabbitmq_api GET "/queues/${VHOST_ENCODED}" | jq -r '.[] | "  - \(.name): \(.messages // 0) mensagens"' 2>/dev/null || echo "  (use jq para ver detalhes)"
echo ""

# Lista os bindings
echo "📋 Bindings configurados para amq.topic:"
rabbitmq_api GET "/bindings/${VHOST_ENCODED}/e/amq.topic" | jq -r '.[] | "  - \(.routing_key) -> \(.destination)"' 2>/dev/null || echo "  (use jq para ver detalhes)"
echo ""

echo "=============================================="
echo "✅ Configuração concluída!"
echo ""
echo "O Arduino publicará nos tópicos MQTT:"
echo "  - water-level -> water-level-queue"
echo "  - water-flux -> water-flux-queue"
echo "  - pump-status -> (não configurado/ignorado)"
echo ""
echo "O fa-data-consumer deve consumir:"
echo "  - WATER_LEVEL_QUEUE=water-level-queue"
echo "  - WATER_FLUX_QUEUE=water-flux-queue"
echo "=============================================="
