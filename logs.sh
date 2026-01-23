#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretório base (pasta pai de fa-scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Farm Automation - Logs${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Menu de seleção
echo -e "Selecione qual log deseja ver:"
echo -e "  ${YELLOW}1)${NC} Backend (fa-auth-service)"
echo -e "  ${YELLOW}2)${NC} Frontend (fa-admin-web)"
echo -e "  ${YELLOW}3)${NC} MongoDB"
echo -e "  ${YELLOW}4)${NC} Todos"
echo -e "  ${YELLOW}q)${NC} Sair"
echo ""
read -p "Opção: " opcao

case $opcao in
    1)
        echo -e "${BLUE}Logs do Backend:${NC}"
        echo ""
        AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"
        if [ -f "$AUTH_SERVICE_DIR/logs/backend.log" ]; then
            tail -f "$AUTH_SERVICE_DIR/logs/backend.log"
        else
            echo -e "${RED}Arquivo de log não encontrado${NC}"
            echo "Caminho esperado: $AUTH_SERVICE_DIR/logs/backend.log"
        fi
        ;;
    2)
        echo -e "${BLUE}Logs do Frontend:${NC}"
        echo ""
        FRONTEND_DIR="$BASE_DIR/fa-admin-web"
        if [ -f "$FRONTEND_DIR/logs/frontend.log" ]; then
            tail -f "$FRONTEND_DIR/logs/frontend.log"
        else
            echo -e "${RED}Arquivo de log não encontrado${NC}"
            echo "Caminho esperado: $FRONTEND_DIR/logs/frontend.log"
        fi
        ;;
    3)
        echo -e "${BLUE}Logs do MongoDB:${NC}"
        echo ""
        if docker ps | grep -q "fa-mongodb"; then
            docker logs -f fa-mongodb
        else
            echo -e "${RED}Container MongoDB não está rodando${NC}"
        fi
        ;;
    4)
        echo -e "${BLUE}Logs de Todos os Serviços:${NC}"
        echo ""
        echo -e "${YELLOW}Pressione Ctrl+C para sair${NC}"
        echo ""
        
        AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"
        FRONTEND_DIR="$BASE_DIR/fa-admin-web"
        
        # Criar named pipes para multiplexar logs
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT
        
        # Backend logs
        if [ -f "$AUTH_SERVICE_DIR/logs/backend.log" ]; then
            tail -f "$AUTH_SERVICE_DIR/logs/backend.log" | sed "s/^/[${GREEN}BACKEND${NC}] /" &
            BACKEND_PID=$!
        fi
        
        # Frontend logs
        if [ -f "$FRONTEND_DIR/logs/frontend.log" ]; then
            tail -f "$FRONTEND_DIR/logs/frontend.log" | sed "s/^/[${BLUE}FRONTEND${NC}] /" &
            FRONTEND_PID=$!
        fi
        
        # MongoDB logs
        if docker ps | grep -q "fa-mongodb"; then
            docker logs -f fa-mongodb 2>&1 | sed "s/^/[${YELLOW}MONGODB${NC}] /" &
            MONGO_PID=$!
        fi
        
        # Aguardar até Ctrl+C
        wait
        ;;
    q|Q)
        echo -e "${BLUE}Saindo...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Opção inválida${NC}"
        exit 1
        ;;
esac
