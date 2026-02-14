#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Farm Automation - Iniciar Tudo${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Diretório base (pasta pai de fa-scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
echo -e "${YELLOW}Verificando dependências...${NC}"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker não encontrado. Por favor, instale o Docker.${NC}"
    exit 1
fi

if ! command_exists go; then
    echo -e "${RED}❌ Go não encontrado. Por favor, instale o Go.${NC}"
    exit 1
fi

if ! command_exists node; then
    echo -e "${RED}❌ Node.js não encontrado. Por favor, instale o Node.js.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Todas as dependências instaladas${NC}"
echo ""

# Função para matar processos usando portas específicas
kill_port() {
    local PORT=$1
    local PORT_NAME=$2
    
    if command_exists lsof; then
        PID=$(lsof -ti:$PORT 2>/dev/null)
        if [ ! -z "$PID" ]; then
            echo -e "${YELLOW}⚠ Porta $PORT ($PORT_NAME) em uso pelo processo $PID${NC}"
            kill -9 $PID 2>/dev/null
            echo -e "${GREEN}✓ Processo na porta $PORT finalizado${NC}"
            sleep 1
        fi
    elif command_exists fuser; then
        fuser -k $PORT/tcp 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Processo na porta $PORT finalizado${NC}"
            sleep 1
        fi
    fi
}

# Limpar portas em uso (exceto MongoDB)
echo -e "${YELLOW}Verificando e limpando portas em uso...${NC}"

kill_port 8080 "Auth Service"
kill_port 8083 "Schedule Service"
kill_port 8084 "Stock Service"
kill_port 3000 "BFF"
kill_port 5173 "Frontend"

echo -e "${GREEN}✓ Portas verificadas e limpas${NC}"
echo ""

# Verificar se há MongoDB rodando na porta 27017
echo -e "${YELLOW}Verificando MongoDB...${NC}"

# Verificar se já existe MongoDB rodando na porta 27017
if docker ps | grep -q "fa-mongodb"; then
    # Nosso MongoDB com credenciais padrão
    MONGO_URI="mongodb://admin:admin123@localhost:27017/farm_automation?authSource=admin"
    echo -e "${GREEN}✓ MongoDB fa-mongodb já está rodando${NC}"
    echo -e "   URL: $MONGO_URI"
elif lsof -Pi :27017 -sTCP:LISTEN -t >/dev/null 2>&1 || docker ps | grep -q ":27017->"; then
    # MongoDB externo - tentar root/root primeiro
    MONGO_URI="mongodb://root:root@localhost:27017/farm_automation?authSource=admin"
    echo -e "${GREEN}✓ MongoDB existente detectado na porta 27017${NC}"
    echo -e "   Usando credenciais: root/root"
    echo -e "   URL: $MONGO_URI"
else
    # Parar container fa-mongodb anterior se existir
    if docker ps -a | grep -q "fa-mongodb"; then
        echo -e "${YELLOW}Removendo container fa-mongodb anterior...${NC}"
        docker stop fa-mongodb >/dev/null 2>&1
        docker rm fa-mongodb >/dev/null 2>&1
    fi
    
    # Iniciar novo MongoDB
    echo -e "${BLUE}1. Iniciando MongoDB...${NC}"
    docker run -d \
        --name fa-mongodb \
        -p 27017:27017 \
        -e MONGO_INITDB_ROOT_USERNAME=admin \
        -e MONGO_INITDB_ROOT_PASSWORD=admin123 \
        -e MONGO_INITDB_DATABASE=farm_automation \
        -v fa-mongodb-data:/data/db \
        mongo:7.0

    if [ $? -eq 0 ]; then
        MONGO_URI="mongodb://admin:admin123@localhost:27017/farm_automation?authSource=admin"
        echo -e "${GREEN}✓ MongoDB iniciado com sucesso${NC}"
        echo -e "   URL: $MONGO_URI"
        echo -e "   Database: farm_automation"
        
        # Aguardar MongoDB estar pronto
        echo -e "${YELLOW}Aguardando MongoDB estar pronto...${NC}"
        sleep 5
    else
        echo -e "${RED}❌ Erro ao iniciar MongoDB${NC}"
        exit 1
    fi
fi

# 2. Configurar e iniciar Backend (fa-auth-service)
echo ""
echo -e "${BLUE}2. Configurando Backend (fa-auth-service)...${NC}"

AUTH_SERVICE_DIR="$BASE_DIR/fa-auth-service"

if [ ! -d "$AUTH_SERVICE_DIR" ]; then
    echo -e "${RED}❌ Diretório fa-auth-service não encontrado${NC}"
    exit 1
fi

cd "$AUTH_SERVICE_DIR"

# Criar .env se não existir ou atualizar MONGO_URI
if [ ! -f .env ]; then
    echo -e "${YELLOW}Criando arquivo .env...${NC}"
    cat > .env << EOF
MONGO_URI=${MONGO_URI}
MONGO_DATABASE=farm_automation
JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026
JWT_EXPIRATION=24h
SERVER_PORT=8080
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
EMAIL_FROM=noreply@farmautomation.com
FRONTEND_URL=http://localhost:5173
ENVIRONMENT=development
EOF
    echo -e "${GREEN}✓ Arquivo .env criado${NC}"
else
    # Atualizar MONGO_URI no .env existente
    echo -e "${YELLOW}Atualizando MONGO_URI no .env...${NC}"
    sed -i "s|^MONGO_URI=.*|MONGO_URI=${MONGO_URI}|" .env
    echo -e "${GREEN}✓ MONGO_URI atualizado${NC}"
fi

# Baixar dependências Go
echo -e "${YELLOW}Baixando dependências Go...${NC}"
go mod download

# Compilar
echo -e "${YELLOW}Compilando backend...${NC}"
go build -o bin/fa-auth-service cmd/api/main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backend compilado com sucesso${NC}"
else
    echo -e "${RED}❌ Erro ao compilar backend${NC}"
    exit 1
fi

# Criar usuário admin
echo -e "${YELLOW}Criando usuário admin padrão...${NC}"
go run cmd/seed/main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Usuário admin criado${NC}"
    echo -e "   Email: admin@farmautomation.com"
    echo -e "   Senha: Admin@123"
else
    echo -e "${YELLOW}⚠ Usuário admin pode já existir (ignorando erro)${NC}"
fi

# Iniciar backend em background
echo -e "${YELLOW}Iniciando backend...${NC}"
nohup ./bin/fa-auth-service > logs/backend.log 2>&1 &
BACKEND_PID=$!
echo $BACKEND_PID > .backend.pid

sleep 3

# Verificar se backend está rodando
if kill -0 $BACKEND_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Backend iniciado (PID: $BACKEND_PID)${NC}"
    echo -e "   URL: http://localhost:8080"
    echo -e "   Health: http://localhost:8080/health"
else
    echo -e "${RED}❌ Erro ao iniciar backend${NC}"
    cat logs/backend.log
    exit 1
fi

# 3. Configurar e iniciar Schedule Service (fa-schedule-service)
echo ""
echo -e "${BLUE}3. Configurando Schedule Service (fa-schedule-service)...${NC}"

SCHEDULE_DIR="$BASE_DIR/fa-schedule-service"

if [ ! -d "$SCHEDULE_DIR" ]; then
    echo -e "${YELLOW}⚠ Diretório fa-schedule-service não encontrado (serviço opcional)${NC}"
else
    cd "$SCHEDULE_DIR"

    # Criar .env se não existir ou atualizar JWT_SECRET
    if [ ! -f .env ]; then
        echo -e "${YELLOW}Criando arquivo .env para Schedule Service...${NC}"
        cat > .env << EOF
MONGODB_URI=mongodb://root:root@localhost:27017
MONGODB_DATABASE=farm_automation_schedule
JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026
PORT=8083
EOF
        echo -e "${GREEN}✓ Arquivo .env criado${NC}"
    else
        echo -e "${YELLOW}Atualizando JWT_SECRET no .env...${NC}"
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026|" .env
        echo -e "${GREEN}✓ JWT_SECRET atualizado${NC}"
    fi

    # Baixar dependências Go
    echo -e "${YELLOW}Baixando dependências Go...${NC}"
    go mod download

    # Compilar
    echo -e "${YELLOW}Compilando Schedule Service...${NC}"
    go build -o bin/fa-schedule-service cmd/api/main.go

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Schedule Service compilado com sucesso${NC}"
    else
        echo -e "${RED}❌ Erro ao compilar Schedule Service${NC}"
        exit 1
    fi

    # Criar diretório de logs se não existir
    mkdir -p logs

    # Iniciar Schedule Service em background
    echo -e "${YELLOW}Iniciando Schedule Service...${NC}"
    nohup ./bin/fa-schedule-service > logs/schedule.log 2>&1 &
    SCHEDULE_PID=$!
    echo $SCHEDULE_PID > .schedule.pid

    sleep 3

    # Verificar se Schedule Service está rodando
    if kill -0 $SCHEDULE_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Schedule Service iniciado (PID: $SCHEDULE_PID)${NC}"
        echo -e "   URL: http://localhost:8083"
        echo -e "   Health: http://localhost:8083/health"
    else
        echo -e "${RED}❌ Erro ao iniciar Schedule Service${NC}"
        cat logs/schedule.log
        exit 1
    fi
fi

# 4. Configurar e iniciar Stock Service (fa-stock-service)
echo ""
echo -e "${BLUE}4. Configurando Stock Service (fa-stock-service)...${NC}"

STOCK_DIR="$BASE_DIR/fa-stock-service"

if [ ! -d "$STOCK_DIR" ]; then
    echo -e "${YELLOW}⚠ Diretório fa-stock-service não encontrado (serviço opcional)${NC}"
else
    cd "$STOCK_DIR"

    # Criar .env se não existir
    if [ ! -f .env ]; then
        echo -e "${YELLOW}Criando arquivo .env para Stock Service...${NC}"
        cat > .env << EOF
MONGODB_URI=mongodb://root:root@localhost:27017
MONGODB_DATABASE=farm_automation_stock
JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026
PORT=8084
EOF
        echo -e "${GREEN}✓ Arquivo .env criado${NC}"
    else
        echo -e "${YELLOW}Atualizando JWT_SECRET no .env...${NC}"
        sed -i "s|^JWT_SECRET=.*|JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026|" .env
        echo -e "${GREEN}✓ JWT_SECRET atualizado${NC}"
    fi

    # Baixar dependências Go
    echo -e "${YELLOW}Baixando dependências Go...${NC}"
    go mod download

    # Compilar
    echo -e "${YELLOW}Compilando Stock Service...${NC}"
    go build -o bin/fa-stock-service cmd/api/main.go

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Stock Service compilado com sucesso${NC}"
    else
        echo -e "${RED}❌ Erro ao compilar Stock Service${NC}"
        exit 1
    fi

    # Criar diretório de logs se não existir
    mkdir -p logs

    # Iniciar Stock Service em background
    echo -e "${YELLOW}Iniciando Stock Service...${NC}"
    nohup ./bin/fa-stock-service > logs/stock.log 2>&1 &
    STOCK_PID=$!
    echo $STOCK_PID > .stock.pid

    sleep 3

    # Verificar se Stock Service está rodando
    if kill -0 $STOCK_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Stock Service iniciado (PID: $STOCK_PID)${NC}"
        echo -e "   URL: http://localhost:8084"
        echo -e "   Health: http://localhost:8084/health"
    else
        echo -e "${RED}❌ Erro ao iniciar Stock Service${NC}"
        cat logs/stock.log
        exit 1
    fi
fi

# 5. Configurar e iniciar BFF (fa-admin-bff)
echo ""
echo -e "${BLUE}5. Configurando BFF (fa-admin-bff)...${NC}"

BFF_DIR="$BASE_DIR/fa-admin-bff"

if [ ! -d "$BFF_DIR" ]; then
    echo -e "${RED}❌ Diretório fa-admin-bff não encontrado${NC}"
    exit 1
fi

cd "$BFF_DIR"

# Criar .env se não existir ou atualizar
if [ ! -f .env ]; then
    echo -e "${YELLOW}Criando arquivo .env...${NC}"
    cat > .env << EOF
PORT=3000
JWT_SECRET=chacara-romanini-secret-key-2026
AUTH_SERVICE_URL=http://localhost:8080
SCHEDULE_SERVICE_URL=http://localhost:8083
STOCK_SERVICE_URL=http://localhost:8084
OPENWEATHER_API_KEY=
EOF
    echo -e "${GREEN}✓ Arquivo .env criado${NC}"
else
    echo -e "${YELLOW}Atualizando .env...${NC}"
    sed -i "s|^PORT=.*|PORT=3000|" .env
    sed -i "s|^AUTH_SERVICE_URL=.*|AUTH_SERVICE_URL=http://localhost:8080|" .env
    # Adicionar SCHEDULE_SERVICE_URL se não existir
    if ! grep -q "SCHEDULE_SERVICE_URL" .env; then
        echo "SCHEDULE_SERVICE_URL=http://localhost:8083" >> .env
    else
        sed -i "s|^SCHEDULE_SERVICE_URL=.*|SCHEDULE_SERVICE_URL=http://localhost:8083|" .env
    fi
    # Adicionar STOCK_SERVICE_URL se não existir
    if ! grep -q "STOCK_SERVICE_URL" .env; then
        echo "STOCK_SERVICE_URL=http://localhost:8084" >> .env
    else
        sed -i "s|^STOCK_SERVICE_URL=.*|STOCK_SERVICE_URL=http://localhost:8084|" .env
    fi
    echo -e "${GREEN}✓ .env atualizado${NC}"
fi

# Baixar dependências Go
echo -e "${YELLOW}Baixando dependências Go...${NC}"
go mod download

# Compilar
echo -e "${YELLOW}Compilando BFF...${NC}"
go build -o bin/fa-admin-bff cmd/api/main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ BFF compilado com sucesso${NC}"
else
    echo -e "${RED}❌ Erro ao compilar BFF${NC}"
    exit 1
fi

# Criar diretório de logs se não existir
mkdir -p logs

# Iniciar BFF em background
echo -e "${YELLOW}Iniciando BFF...${NC}"
nohup ./bin/fa-admin-bff > logs/bff.log 2>&1 &
BFF_PID=$!
echo $BFF_PID > .bff.pid

sleep 3

# Verificar se BFF está rodando
if kill -0 $BFF_PID 2>/dev/null; then
    echo -e "${GREEN}✓ BFF iniciado (PID: $BFF_PID)${NC}"
    echo -e "   URL: http://localhost:3000"
    echo -e "   Health: http://localhost:3000/health"
else
    echo -e "${RED}❌ Erro ao iniciar BFF${NC}"
    cat logs/bff.log
    exit 1
fi

# 6. Configurar e iniciar Frontend (fa-admin-web)
echo ""
echo -e "${BLUE}6. Configurando Frontend (fa-admin-web)...${NC}"

FRONTEND_DIR="$BASE_DIR/fa-admin-web"

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}❌ Diretório fa-admin-web não encontrado${NC}"
    exit 1
fi

cd "$FRONTEND_DIR"

# Criar .env se não existir
if [ ! -f .env ]; then
    echo -e "${YELLOW}Criando arquivo .env...${NC}"
    cat > .env << EOF
VITE_API_URL=http://localhost:8080/api/v1
EOF
    echo -e "${GREEN}✓ Arquivo .env criado${NC}"
fi

# Instalar dependências npm se necessário
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Instalando dependências npm...${NC}"
    npm install
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Dependências instaladas${NC}"
    else
        echo -e "${RED}❌ Erro ao instalar dependências${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Dependências npm já instaladas${NC}"
fi

# Iniciar frontend em background
echo -e "${YELLOW}Iniciando frontend...${NC}"
nohup npm run dev > logs/frontend.log 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > .frontend.pid

sleep 5

if kill -0 $FRONTEND_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Frontend iniciado (PID: $FRONTEND_PID)${NC}"
    echo -e "   URL: http://localhost:5173"
else
    echo -e "${RED}❌ Erro ao iniciar frontend${NC}"
    cat logs/frontend.log
    exit 1
fi

# Resumo final
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ Todos os serviços iniciados!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Serviços rodando:${NC}"
echo -e "  ${YELLOW}MongoDB:${NC}          mongodb://root:root@localhost:27017"
echo -e "  ${YELLOW}Auth Service:${NC}     http://localhost:8080"
echo -e "  ${YELLOW}Schedule Service:${NC} http://localhost:8083"
echo -e "  ${YELLOW}Stock Service:${NC}    http://localhost:8084"
echo -e "  ${YELLOW}BFF:${NC}              http://localhost:3000"
echo -e "  ${YELLOW}Frontend:${NC}         http://localhost:5173"
echo ""
echo -e "${BLUE}Credenciais padrão:${NC}"
echo -e "  ${YELLOW}Email:${NC}       admin@farmautomation.com"
echo -e "  ${YELLOW}Senha:${NC}       Admin@123"
echo ""
echo -e "${BLUE}Comandos úteis:${NC}"
echo -e "  ${YELLOW}Parar tudo:${NC}       ./stop-all.sh"
echo -e "  ${YELLOW}Ver logs:${NC}          ./logs.sh"
echo -e "  ${YELLOW}Resetar tudo:${NC}     ./reset-all.sh"
echo -e "  ${YELLOW}Status:${NC}            ./status.sh"
echo ""
echo -e "${GREEN}Acesse: http://localhost:5173${NC}"
echo -e "${YELLOW}Nota:${NC} O frontend se comunica com o BFF, que roteia para os serviços"
echo ""
