#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}================================${NC}"
echo -e "${RED}Farm Automation - Resetar Tudo${NC}"
echo -e "${RED}================================${NC}"
echo ""
echo -e "${YELLOW}ATENÇÃO: Isso irá remover TODOS os dados!${NC}"
echo -e "${YELLOW}         - MongoDB (todos os usuários e tokens)${NC}"
echo -e "${YELLOW}         - Logs das aplicações${NC}"
echo ""
read -p "Tem certeza? (digite 'sim' para confirmar): " confirmacao

if [ "$confirmacao" != "sim" ]; then
    echo -e "${BLUE}Operação cancelada.${NC}"
    exit 0
fi

echo ""

# Diretório base (pasta pai de fa-scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Parar tudo primeiro
echo -e "${YELLOW}Parando todos os serviços...${NC}"
"$BASE_DIR/stop-all.sh"

echo ""

# Remover container MongoDB e volume
echo -e "${YELLOW}Removendo MongoDB e dados...${NC}"
docker rm fa-mongodb >/dev/null 2>&1
docker volume rm fa-mongodb-data >/dev/null 2>&1
echo -e "${GREEN}✓ MongoDB e dados removidos${NC}"

# Limpar logs backend
AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"
if [ -d "$AUTH_SERVICE_DIR/logs" ]; then
    echo -e "${YELLOW}Limpando logs do backend...${NC}"
    rm -f "$AUTH_SERVICE_DIR/logs"/*.log
    echo -e "${GREEN}✓ Logs do backend limpos${NC}"
fi

# Limpar logs frontend
FRONTEND_DIR="$BASE_DIR/fa-admin-web"
if [ -d "$FRONTEND_DIR/logs" ]; then
    echo -e "${YELLOW}Limpando logs do frontend...${NC}"
    rm -f "$FRONTEND_DIR/logs"/*.log
    echo -e "${GREEN}✓ Logs do frontend limpos${NC}"
fi

# Remover binário compilado
if [ -f "$AUTH_SERVICE_DIR/bin/fa-auth-service" ]; then
    echo -e "${YELLOW}Removendo binário compilado...${NC}"
    rm "$AUTH_SERVICE_DIR/bin/fa-auth-service"
    echo -e "${GREEN}✓ Binário removido${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ Reset completo realizado!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo -e "  1. Execute ${YELLOW}./start-all.sh${NC} para iniciar tudo novamente"
echo -e "  2. Um novo usuário admin será criado"
echo ""
