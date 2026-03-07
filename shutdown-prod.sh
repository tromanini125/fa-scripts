#!/bin/bash

# ============================================================
# shutdown-prod.sh — Para/remove serviços em produção (OKE)
# ============================================================
# ⚠️  CUIDADO: este script afeta o ambiente de PRODUÇÃO!
#
# Uso:
#   ./shutdown-prod.sh           → scale down (replicas=0) todos os serviços
#   ./shutdown-prod.sh --delete  → deleta todos os deployments (mais agressivo)
#   ./shutdown-prod.sh --resume  → scale up (replicas=1) todos os serviços
# ============================================================

set -e

NAMESPACE="farm-automation"
PROD_CONTEXT="farm-automation-oke"   # ajuste se diferente

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_bold="\033[1m"
_reset="\033[0m"

MODE="${1:-scaledown}"

DEPLOYMENTS=(
  "fa-auth-service"
  "fa-schedule-service"
  "fa-stock-service"
  "fa-finance-service"
  "fa-data-consumer"
  "fa-admin-bff"
  "fa-admin-web"
)

echo -e "${_red}${_bold}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_red}${_bold}║   ⚠️  OPERAÇÃO EM PRODUÇÃO (OKE)                 ║${_reset}"
echo -e "${_red}${_bold}╚══════════════════════════════════════════════════╝${_reset}"
echo ""

# ─── Mudar para contexto de produção ───
echo -e "${_cyan}🔄 Alternando para contexto de produção...${_reset}"
kubectl config use-context "${PROD_CONTEXT}"
kubectl config set-context "${PROD_CONTEXT}" --namespace="${NAMESPACE}"
echo -e "${_green}✅ Contexto: ${PROD_CONTEXT}${_reset}"
echo ""

case "$MODE" in
  --delete|delete)
    echo -e "${_red}🗑️  DELETAR todos os deployments em produção?${_reset}"
    read -rp "🔴 Digite 'CONFIRMAR' para prosseguir: " CONFIRM
    if [[ "$CONFIRM" != "CONFIRMAR" ]]; then
      echo "Abortado."
      exit 0
    fi

    for dep in "${DEPLOYMENTS[@]}"; do
      if kubectl get deployment "$dep" -n "${NAMESPACE}" &>/dev/null; then
        kubectl delete deployment "$dep" -n "${NAMESPACE}"
        echo -e "  ${_green}✅ ${dep} deletado${_reset}"
      fi
    done
    echo ""
    echo -e "${_green}✅ Deployments deletados.${_reset}"
    ;;

  --resume|resume|up)
    echo -e "${_green}🚀 Restaurando replicas para 1 em produção...${_reset}"
    read -rp "Confirmar? [s/N] " CONFIRM
    if [[ ! "${CONFIRM}" =~ ^[sS]$ ]]; then
      echo "Abortado."
      exit 0
    fi

    for dep in "${DEPLOYMENTS[@]}"; do
      if kubectl get deployment "$dep" -n "${NAMESPACE}" &>/dev/null; then
        kubectl scale deployment "$dep" -n "${NAMESPACE}" --replicas=1
        echo -e "  ${_green}✅ ${dep} → 1 replica${_reset}"
      fi
    done
    echo ""
    echo -e "${_green}✅ Serviços restaurados.${_reset}"
    ;;

  *)
    echo -e "${_yellow}🔽 Scale down (replicas=0) de todos os serviços em produção...${_reset}"
    read -rp "🔴 Tem certeza que deseja desligar PRODUÇÃO? [s/N] " CONFIRM
    if [[ ! "${CONFIRM}" =~ ^[sS]$ ]]; then
      echo "Abortado."
      exit 0
    fi

    for dep in "${DEPLOYMENTS[@]}"; do
      if kubectl get deployment "$dep" -n "${NAMESPACE}" &>/dev/null; then
        kubectl scale deployment "$dep" -n "${NAMESPACE}" --replicas=0
        echo -e "  ${_yellow}⏸️  ${dep} → 0 replicas${_reset}"
      fi
    done

    echo ""
    echo -e "${_yellow}✅ Todos os serviços desligados (scale=0).${_reset}"
    echo -e "${_yellow}   Para restaurar: ./shutdown-prod.sh --resume${_reset}"
    ;;
esac

echo ""
echo -e "${_cyan}📊 Status atual:${_reset}"
kubectl get pods -n "${NAMESPACE}" 2>/dev/null || echo "(nenhum pod)"
