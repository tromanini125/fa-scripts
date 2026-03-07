#!/bin/bash

# ============================================================
# minikube-setup.sh — Inicializa o Minikube para o farm-automation
# ============================================================
# Cria o cluster Minikube, habilita addons necessários
# e prepara o namespace farm-automation.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="farm-automation"

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_reset="\033[0m"

echo -e "${_cyan}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_cyan}║   Farm Automation — Minikube Setup               ║${_reset}"
echo -e "${_cyan}╚══════════════════════════════════════════════════╝${_reset}"
echo ""

# ─── Verificar pré-requisitos ───
for cmd in minikube kubectl docker; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${_red}❌ '${cmd}' não encontrado. Instale antes de continuar.${_reset}"
    exit 1
  fi
done

# ─── Verificar se Minikube já está rodando ───
MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")

if [[ "$MINIKUBE_STATUS" == "Running" ]]; then
  echo -e "${_yellow}⚠️  Minikube já está rodando.${_reset}"
  read -rp "Deseja continuar e reconfigurar? [s/N] " CONFIRM
  if [[ ! "${CONFIRM}" =~ ^[sS]$ ]]; then
    echo "Abortado."
    exit 0
  fi
else
  echo -e "${_green}🚀 Iniciando Minikube...${_reset}"
  minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=6144 \
    --disk-size=30g \
    --kubernetes-version=v1.28.0 \
    --extra-config=apiserver.service-node-port-range=1-65535

  echo -e "${_green}✅ Minikube iniciado.${_reset}"
fi

# ─── Habilitar addons ───
echo ""
echo -e "${_cyan}🔧 Habilitando addons...${_reset}"
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard
echo -e "${_green}✅ Addons habilitados.${_reset}"

# ─── Criar namespace ───
echo ""
echo -e "${_cyan}📦 Criando namespace '${NAMESPACE}'...${_reset}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context minikube --namespace="${NAMESPACE}"
echo -e "${_green}✅ Namespace '${NAMESPACE}' pronto.${_reset}"

# ─── Criar secrets base ───
echo ""
echo -e "${_cyan}🔐 Criando secrets...${_reset}"

# MongoDB local (rodando no Minikube)
kubectl create secret generic mongodb-secret \
  --namespace="${NAMESPACE}" \
  --from-literal=mongodb-uri="mongodb://admin:admin123@mongodb.${NAMESPACE}.svc.cluster.local:27017/admin" \
  --dry-run=client -o yaml | kubectl apply -f -

# JWT Secret (compartilhado entre serviços)
kubectl create secret generic fa-admin-bff-secret \
  --namespace="${NAMESPACE}" \
  --from-literal=JWT_SECRET="farm-automation-local-jwt-secret-2026" \
  --dry-run=client -o yaml | kubectl apply -f -

# RabbitMQ para data-consumer
kubectl create secret generic fa-data-consumer-rabbitmq \
  --namespace="${NAMESPACE}" \
  --from-literal=rabbitmq-url="amqp://guest:guest@rabbitmq.${NAMESPACE}.svc.cluster.local:5672/" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${_green}✅ Secrets criados.${_reset}"

# ─── Aplicar infraestrutura (MongoDB + RabbitMQ) ───
echo ""
echo -e "${_cyan}🗄️  Aplicando infraestrutura local (MongoDB + RabbitMQ)...${_reset}"
kubectl apply -f "${SCRIPT_DIR}/minikube/infra/" --namespace="${NAMESPACE}"
echo -e "${_green}✅ Infraestrutura aplicada.${_reset}"

# ─── Aguardar MongoDB e RabbitMQ ficarem prontos ───
echo ""
echo -e "${_cyan}⏳ Aguardando MongoDB e RabbitMQ ficarem prontos...${_reset}"
kubectl wait --for=condition=ready pod -l app=mongodb -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=rabbitmq -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true
echo -e "${_green}✅ Infraestrutura pronta.${_reset}"

echo ""
echo -e "${_green}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_green}║   Minikube configurado com sucesso!              ║${_reset}"
echo -e "${_green}╚══════════════════════════════════════════════════╝${_reset}"
echo ""
echo -e "Próximo passo: ${_yellow}./deploy-local.sh${_reset} para buildar e deployar os serviços."
