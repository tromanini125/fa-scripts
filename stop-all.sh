#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Farm Automation - Parar Tudo${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Diretório base (pasta pai de fa-scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Parar Frontend
echo -e "${YELLOW}Parando frontend...${NC}"
FRONTEND_DIR="$BASE_DIR/fa-admin-web"
if [ -f "$FRONTEND_DIR/.frontend.pid" ]; then
    FRONTEND_PID=$(cat "$FRONTEND_DIR/.frontend.pid")
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        kill $FRONTEND_PID
        echo -e "${GREEN}✓ Frontend parado (PID: $FRONTEND_PID)${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend já estava parado${NC}"
    fi
    rm "$FRONTEND_DIR/.frontend.pid"
else
    echo -e "${YELLOW}⚠ PID do frontend não encontrado${NC}"
fi

# Parar BFF
echo -e "${YELLOW}Parando BFF...${NC}"
BFF_DIR="$BASE_DIR/fa-admin-bff"
if [ -f "$BFF_DIR/.bff.pid" ]; then
    BFF_PID=$(cat "$BFF_DIR/.bff.pid")
    if kill -0 $BFF_PID 2>/dev/null; then
        kill $BFF_PID
        echo -e "${GREEN}✓ BFF parado (PID: $BFF_PID)${NC}"
    else
        echo -e "${YELLOW}⚠ BFF já estava parado${NC}"
    fi
    rm "$BFF_DIR/.bff.pid"
else
    echo -e "${YELLOW}⚠ PID do BFF não encontrado${NC}"
fi

# Parar Schedule Service
echo -e "${YELLOW}Parando Schedule Service...${NC}"
SCHEDULE_DIR="$BASE_DIR/fa-schedule-service"
if [ -f "$SCHEDULE_DIR/.schedule.pid" ]; then
    SCHEDULE_PID=$(cat "$SCHEDULE_DIR/.schedule.pid")
    if kill -0 $SCHEDULE_PID 2>/dev/null; then
        kill $SCHEDULE_PID
        echo -e "${GREEN}✓ Schedule Service parado (PID: $SCHEDULE_PID)${NC}"
    else
        echo -e "${YELLOW}⚠ Schedule Service já estava parado${NC}"
    fi
    rm "$SCHEDULE_DIR/.schedule.pid"
else
    echo -e "${YELLOW}⚠ PID do Schedule Service não encontrado${NC}"
fi

# Parar Stock Service
echo -e "${YELLOW}Parando Stock Service...${NC}"
STOCK_DIR="$BASE_DIR/fa-stock-service"
if [ -f "$STOCK_DIR/.stock.pid" ]; then
    STOCK_PID=$(cat "$STOCK_DIR/.stock.pid")
    if kill -0 $STOCK_PID 2>/dev/null; then
        kill $STOCK_PID
        echo -e "${GREEN}✓ Stock Service parado (PID: $STOCK_PID)${NC}"
    else
        echo -e "${YELLOW}⚠ Stock Service já estava parado${NC}"
    fi
    rm "$STOCK_DIR/.stock.pid"
else
    echo -e "${YELLOW}⚠ PID do Stock Service não encontrado${NC}"
fi

# Parar Backend (Auth Service)
echo -e "${YELLOW}Parando Auth Service...${NC}"
AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"
if [ -f "$AUTH_SERVICE_DIR/.backend.pid" ]; then
    BACKEND_PID=$(cat "$AUTH_SERVICE_DIR/.backend.pid")
    if kill -0 $BACKEND_PID 2>/dev/null; then
        kill $BACKEND_PID
        echo -e "${GREEN}✓ Auth Service parado (PID: $BACKEND_PID)${NC}"
    else
        echo -e "${YELLOW}⚠ Auth Service já estava parado${NC}"
    fi
    rm "$AUTH_SERVICE_DIR/.backend.pid"
else
    echo -e "${YELLOW}⚠ PID do Auth Service não encontrado${NC}"
fi

# Parar MongoDB
echo -e "${YELLOW}Parando MongoDB...${NC}"
if docker ps | grep -q "fa-mongodb"; then
    docker stop fa-mongodb >/dev/null 2>&1
    echo -e "${GREEN}✓ MongoDB parado${NC}"
else
    echo -e "${YELLOW}⚠ MongoDB já estava parado${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ Todos os serviços parados!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Nota:${NC} O container MongoDB foi parado mas não removido."
echo -e "       Os dados foram preservados."
echo ""
echo -e "${BLUE}Comandos úteis:${NC}"
echo -e "  ${YELLOW}Reiniciar:${NC}         ./start-all.sh"
echo -e "  ${YELLOW}Resetar dados:${NC}     ./reset-all.sh"
echo -e "  ${YELLOW}Status:${NC}            ./status.sh"
echo ""
