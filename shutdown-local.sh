#!/bin/bash

# ============================================================
# shutdown-local.sh — Para todos os serviços no Minikube
# ============================================================
# Uso:
#   ./shutdown-local.sh          → remove todos os deployments do namespace
#   ./shutdown-local.sh --full   → para o Minikube inteiro
#   ./shutdown-local.sh --delete → deleta o cluster Minikube
# ============================================================

set -e

NAMESPACE="farm-automation"

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_reset="\033[0m"

MODE="${1:-services}"

echo -e "${_cyan}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_cyan}║   Farm Automation — Shutdown Local               ║${_reset}"
echo -e "${_cyan}╚══════════════════════════════════════════════════╝${_reset}"
echo ""

# Garantir contexto correto
CURRENT_CTX=$(kubectl config current-context 2>/dev/null || echo "")
if [[ "$CURRENT_CTX" != "minikube" ]]; then
  echo -e "${_yellow}⚠️  Contexto atual: ${CURRENT_CTX:-nenhum}${_reset}"
  echo -e "${_yellow}   Trocando para minikube...${_reset}"
  kubectl config use-context minikube 2>/dev/null || true
fi

case "$MODE" in
  --full|full|stop)
    echo -e "${_yellow}🛑 Parando Minikube (mas mantendo dados)...${_reset}"
    minikube stop
    echo -e "${_green}✅ Minikube parado. Use 'minikube start' para reiniciar.${_reset}"
    ;;

  --delete|delete)
    echo -e "${_red}🗑️  Deletando cluster Minikube (todos os dados serão perdidos)...${_reset}"
    read -rp "Tem certeza? [s/N] " CONFIRM
    if [[ "${CONFIRM}" =~ ^[sS]$ ]]; then
      minikube delete
      echo -e "${_green}✅ Cluster Minikube deletado.${_reset}"
    else
      echo "Abortado."
    fi
    ;;

  *)
    echo -e "${_cyan}🛑 Removendo serviços do namespace '${NAMESPACE}'...${_reset}"
    echo ""

    # Deletar deployments dos serviços
    DEPLOYMENTS=(
      "fa-auth-service"
      "fa-schedule-service"
      "fa-stock-service"
      "fa-finance-service"
      "fa-data-consumer"
      "fa-admin-bff"
      "fa-admin-web"
    )

    for dep in "${DEPLOYMENTS[@]}"; do
      if kubectl get deployment "$dep" -n "${NAMESPACE}" &>/dev/null; then
        kubectl delete deployment "$dep" -n "${NAMESPACE}"
        echo -e "  ${_green}✅ ${dep} removido${_reset}"
      else
        echo -e "  ${_yellow}⚬ ${dep} não encontrado${_reset}"
      fi
    done

    # Deletar services
    echo ""
    echo -e "${_cyan}🛑 Removendo services...${_reset}"
    SERVICES=(
      "fa-auth-service"
      "fa-schedule-service"
      "fa-stock-service"
      "fa-finance-service"
      "fa-data-consumer-service"
      "fa-admin-bff"
      "fa-admin-web"
    )

    for svc in "${SERVICES[@]}"; do
      if kubectl get service "$svc" -n "${NAMESPACE}" &>/dev/null; then
        kubectl delete service "$svc" -n "${NAMESPACE}"
        echo -e "  ${_green}✅ svc/${svc} removido${_reset}"
      fi
    done

    # Deletar configmaps
    echo ""
    echo -e "${_cyan}🛑 Removendo configmaps...${_reset}"
    for cm in "fa-admin-bff-config" "fa-admin-web-config"; do
      kubectl delete configmap "$cm" -n "${NAMESPACE}" 2>/dev/null && \
        echo -e "  ${_green}✅ cm/${cm} removido${_reset}" || true
    done

    echo ""
    echo -e "${_green}✅ Serviços removidos. Infra (MongoDB, RabbitMQ) mantida.${_reset}"
    echo -e "${_yellow}   Para parar tudo: ./shutdown-local.sh --full${_reset}"
    echo -e "${_yellow}   Para deletar:    ./shutdown-local.sh --delete${_reset}"
    ;;
esac
