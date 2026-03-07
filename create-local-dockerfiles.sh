#!/bin/bash

# ============================================================
# create-local-dockerfiles.sh — Gera Dockerfile.local para cada serviço Go
# ============================================================
# Os Dockerfiles originais usam GOARCH=arm64 (produção).
# Este script cria Dockerfile.local com GOARCH=amd64 para Minikube.
# Já é chamado automaticamente pelo deploy-local.sh se necessário.
# ============================================================

set -e

FA_BASE="/home/thiago/Documents/Projetos/farm-automation"

_green="\033[0;32m"
_cyan="\033[0;36m"
_reset="\033[0m"

create_go_dockerfile_local() {
  local SERVICE_PATH="$1"
  local SERVICE_NAME="$2"
  local BUILD_CMD="$3"
  local BINARY_NAME="$4"
  local PORT="$5"
  local GO_VERSION="${6:-1.21}"
  local BUILD_OUTPUT="${7:-${BINARY_NAME}}"   # caminho do -o no build
  local COPY_FROM="${8:-/app/${BINARY_NAME}}" # caminho no COPY --from

  local OUTFILE="${SERVICE_PATH}/Dockerfile.local"

  cat > "${OUTFILE}" <<DOCKERFILE
# Dockerfile.local — Build amd64 para Minikube
# Gerado automaticamente. NÃO edite manualmente.
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /app
RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o ${BUILD_OUTPUT} ${BUILD_CMD}

FROM alpine:latest

WORKDIR /root/
RUN apk --no-cache add ca-certificates tzdata

COPY --from=builder ${COPY_FROM} .

ENV TZ=America/Sao_Paulo
EXPOSE ${PORT}

CMD ["./${BINARY_NAME}"]
DOCKERFILE

  echo -e "  ${_green}✅ ${SERVICE_NAME}/Dockerfile.local${_reset}"
}

echo -e "${_cyan}📦 Criando Dockerfile.local para cada serviço Go...${_reset}"
echo ""

create_go_dockerfile_local "${FA_BASE}/fa-auth-service"      "fa-auth-service"      "./cmd/api"          "main"                8080 "1.21" "main" "/app/main"
create_go_dockerfile_local "${FA_BASE}/fa-schedule-service"   "fa-schedule-service"  "./cmd/api"          "fa-schedule-service" 8080 "1.21" "/app/bin/fa-schedule-service" "/app/bin/fa-schedule-service"
create_go_dockerfile_local "${FA_BASE}/fa-stock-service"      "fa-stock-service"     "./cmd/api"          "fa-stock-service"    8080 "1.21" "/app/bin/fa-stock-service" "/app/bin/fa-stock-service"
create_go_dockerfile_local "${FA_BASE}/fa-finance-service"    "fa-finance-service"   "./cmd/api"          "fa-finance-service"  8080 "1.25" "/app/bin/fa-finance-service" "/app/bin/fa-finance-service"
create_go_dockerfile_local "${FA_BASE}/fa-data-consumer"      "fa-data-consumer"     "./cmd/api/main.go"  "fa-data-consumer"    8086 "1.24" "fa-data-consumer" "/app/fa-data-consumer"
create_go_dockerfile_local "${FA_BASE}/fa-admin-bff"          "fa-admin-bff"         "./cmd/api"          "fa-admin-bff"        8080 "1.24" "fa-admin-bff" "/app/fa-admin-bff"

echo ""
echo -e "${_green}✅ Todos os Dockerfile.local criados.${_reset}"
echo -e "${_cyan}   O fa-admin-web usa o Dockerfile padrão (não precisa de Dockerfile.local).${_reset}"
