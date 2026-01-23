#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Farm Automation - Status${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Diretório base (pasta pai de fa-scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Status MongoDB
echo -e "${BLUE}MongoDB:${NC}"
if docker ps | grep -q "fa-mongodb"; then
    MONGO_STATUS="${GREEN}✓ Rodando (fa-mongodb)${NC}"
    MONGO_PORT=$(docker port fa-mongodb 27017 2>/dev/null | cut -d':' -f2)
    echo -e "  Status: $MONGO_STATUS"
    echo -e "  Porta:  27017"
    echo -e "  URL:    mongodb://admin:admin123@localhost:27017"
elif lsof -Pi :27017 -sTCP:LISTEN -t >/dev/null 2>&1 || docker ps | grep -q ":27017->"; then
    MONGO_STATUS="${GREEN}✓ Rodando (externo)${NC}"
    echo -e "  Status: $MONGO_STATUS"
    echo -e "  Porta:  27017"
    echo -e "  URL:    mongodb://root:root@localhost:27017"
else
    echo -e "  Status: ${RED}✗ Parado${NC}"
fi

echo ""

# Status Auth Service
echo -e "${BLUE}Auth Service (fa-auth-service):${NC}"
AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"
if [ -f "$AUTH_SERVICE_DIR/.backend.pid" ]; then
    BACKEND_PID=$(cat "$AUTH_SERVICE_DIR/.backend.pid")
    if kill -0 $BACKEND_PID 2>/dev/null; then
        BACKEND_STATUS="${GREEN}✓ Rodando${NC}"
        echo -e "  Status: $BACKEND_STATUS"
        echo -e "  PID:    $BACKEND_PID"
        echo -e "  URL:    http://localhost:8080"
        
        # Tentar verificar health
        if command -v curl >/dev/null 2>&1; then
            HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo -e "  Health: ${GREEN}✓ OK${NC}"
            else
                echo -e "  Health: ${RED}✗ Não responde${NC}"
            fi
        fi
    else
        echo -e "  Status: ${RED}✗ Parado (PID inválido)${NC}"
        rm "$AUTH_SERVICE_DIR/.backend.pid"
    fi
else
    echo -e "  Status: ${RED}✗ Parado${NC}"
fi

echo ""

# Status Schedule Service
echo -e "${BLUE}Schedule Service (fa-schedule-service):${NC}"
SCHEDULE_DIR="$BASE_DIR/fa-schedule-service"
if [ -f "$SCHEDULE_DIR/.schedule.pid" ]; then
    SCHEDULE_PID=$(cat "$SCHEDULE_DIR/.schedule.pid")
    if kill -0 $SCHEDULE_PID 2>/dev/null; then
        SCHEDULE_STATUS="${GREEN}✓ Rodando${NC}"
        echo -e "  Status: $SCHEDULE_STATUS"
        echo -e "  PID:    $SCHEDULE_PID"
        echo -e "  URL:    http://localhost:8083"
        
        # Tentar verificar health
        if command -v curl >/dev/null 2>&1; then
            HEALTH=$(curl -s http://localhost:8083/health 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo -e "  Health: ${GREEN}✓ OK${NC}"
            else
                echo -e "  Health: ${RED}✗ Não responde${NC}"
            fi
        fi
    else
        echo -e "  Status: ${RED}✗ Parado (PID inválido)${NC}"
        rm "$SCHEDULE_DIR/.schedule.pid"
    fi
else
    echo -e "  Status: ${RED}✗ Parado${NC}"
fi

echo ""

# Status BFF
echo -e "${BLUE}BFF (fa-admin-bff):${NC}"
BFF_DIR="$BASE_DIR/fa-admin-bff"
if [ -f "$BFF_DIR/.bff.pid" ]; then
    BFF_PID=$(cat "$BFF_DIR/.bff.pid")
    if kill -0 $BFF_PID 2>/dev/null; then
        BFF_STATUS="${GREEN}✓ Rodando${NC}"
        echo -e "  Status: $BFF_STATUS"
        echo -e "  PID:    $BFF_PID"
        echo -e "  URL:    http://localhost:3000"
        
        # Tentar verificar health
        if command -v curl >/dev/null 2>&1; then
            HEALTH=$(curl -s http://localhost:3000/health 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo -e "  Health: ${GREEN}✓ OK${NC}"
            else
                echo -e "  Health: ${RED}✗ Não responde${NC}"
            fi
        fi
    else
        echo -e "  Status: ${RED}✗ Parado (PID inválido)${NC}"
        rm "$BFF_DIR/.bff.pid"
    fi
else
    echo -e "  Status: ${RED}✗ Parado${NC}"
fi

echo ""

# Status Frontend
echo -e "${BLUE}Frontend (fa-admin-web):${NC}"
FRONTEND_DIR="$BASE_DIR/fa-admin-web"
if [ -f "$FRONTEND_DIR/.frontend.pid" ]; then
    FRONTEND_PID=$(cat "$FRONTEND_DIR/.frontend.pid")
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        FRONTEND_STATUS="${GREEN}✓ Rodando${NC}"
        echo -e "  Status: $FRONTEND_STATUS"
        echo -e "  PID:    $FRONTEND_PID"
        echo -e "  URL:    http://localhost:5173"
        
        # Tentar verificar se está respondendo
        if command -v curl >/dev/null 2>&1; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 2>/dev/null)
            if [ "$HTTP_CODE" = "200" ]; then
                echo -e "  Health: ${GREEN}✓ OK${NC}"
            else
                echo -e "  Health: ${YELLOW}⚠ Iniciando...${NC}"
            fi
        fi
    else
        echo -e "  Status: ${RED}✗ Parado (PID inválido)${NC}"
        rm "$FRONTEND_DIR/.frontend.pid"
    fi
else
    echo -e "  Status: ${RED}✗ Parado${NC}"
fi

echo ""
echo -e "${BLUE}================================${NC}"

# Verificar se tudo está rodando
MONGO_OK=false
BACKEND_OK=false
BFF_OK=false
FRONTEND_OK=false

if docker ps | grep -q "fa-mongodb" || lsof -Pi :27017 -sTCP:LISTEN -t >/dev/null 2>&1 || docker ps | grep -q ":27017->"; then
    MONGO_OK=true
fi

if [ -f "$AUTH_SERVICE_DIR/.backend.pid" ]; then
    BACKEND_PID=$(cat "$AUTH_SERVICE_DIR/.backend.pid")
    if kill -0 $BACKEND_PID 2>/dev/null; then
        BACKEND_OK=true
    fi
fi

BFF_DIR="$BASE_DIR/fa-admin-bff"
if [ -f "$BFF_DIR/.bff.pid" ]; then
    BFF_PID=$(cat "$BFF_DIR/.bff.pid")
    if kill -0 $BFF_PID 2>/dev/null; then
        BFF_OK=true
    fi
fi

if [ -f "$FRONTEND_DIR/.frontend.pid" ]; then
    FRONTEND_PID=$(cat "$FRONTEND_DIR/.frontend.pid")
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        FRONTEND_OK=true
    fi
fi

if $MONGO_OK && $BACKEND_OK && $BFF_OK && $FRONTEND_OK; then
    echo -e "${GREEN}✓ Todos os serviços estão rodando!${NC}"
    echo ""
    echo -e "${BLUE}Acesse:${NC} http://localhost:5173"
    echo -e "${BLUE}Login:${NC}  admin@farmautomation.com / Admin@123"
    echo -e "${YELLOW}Nota:${NC}  Frontend → BFF (3000) → Auth Service (8080)"
elif $MONGO_OK || $BACKEND_OK || $BFF_OK || $FRONTEND_OK; then
    echo -e "${YELLOW}⚠ Alguns serviços não estão rodando${NC}"
    echo ""
    echo -e "${BLUE}Comandos úteis:${NC}"
    echo -e "  ${YELLOW}Iniciar tudo:${NC}  ./start-all.sh"
    echo -e "  ${YELLOW}Parar tudo:${NC}    ./stop-all.sh"
else
    echo -e "${RED}✗ Nenhum serviço está rodando${NC}"
    echo ""
    echo -e "${BLUE}Comando:${NC}"
    echo -e "  ${YELLOW}Iniciar tudo:${NC}  ./start-all.sh"
fi

echo ""
