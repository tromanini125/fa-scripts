#!/bin/bash

# ============================================================
# fa-env.sh — Alterna contexto kubectl entre DEV (Minikube) e PROD (OKE)
# ============================================================
# Uso:
#   source fa-env.sh dev    → muda para Minikube
#   source fa-env.sh prod   → muda para OKE (Oracle)
#   source fa-env.sh status → mostra contexto atual
#
# IMPORTANTE: use "source" ou "." para que as variáveis de ambiente
# sejam aplicadas no shell corrente.
# ============================================================

set -e

FA_MINIKUBE_CONTEXT="minikube"
FA_PROD_CONTEXT="farm-automation-oke"   # ajuste se o nome do contexto OKE for diferente
FA_NAMESPACE="farm-automation"

_fa_color_green="\033[0;32m"
_fa_color_yellow="\033[0;33m"
_fa_color_cyan="\033[0;36m"
_fa_color_red="\033[0;31m"
_fa_color_reset="\033[0m"

fa_show_context() {
  local ctx
  ctx=$(kubectl config current-context 2>/dev/null || echo "(nenhum)")
  echo -e "${_fa_color_cyan}📌 Contexto kubectl atual: ${_fa_color_yellow}${ctx}${_fa_color_reset}"
  echo -e "${_fa_color_cyan}📌 Namespace padrão:       ${_fa_color_yellow}$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo 'default')${_fa_color_reset}"
}

fa_use_dev() {
  echo -e "${_fa_color_green}🔄 Alternando para DEV (Minikube)...${_fa_color_reset}"
  kubectl config use-context "${FA_MINIKUBE_CONTEXT}"
  kubectl config set-context "${FA_MINIKUBE_CONTEXT}" --namespace="${FA_NAMESPACE}"
  export FA_ENV="dev"
  echo -e "${_fa_color_green}✅ Contexto: DEV (Minikube) | Namespace: ${FA_NAMESPACE}${_fa_color_reset}"
}

fa_use_prod() {
  echo -e "${_fa_color_yellow}🔄 Alternando para PROD (OKE)...${_fa_color_reset}"
  kubectl config use-context "${FA_PROD_CONTEXT}"
  kubectl config set-context "${FA_PROD_CONTEXT}" --namespace="${FA_NAMESPACE}"
  export FA_ENV="prod"
  echo -e "${_fa_color_yellow}✅ Contexto: PROD (OKE) | Namespace: ${FA_NAMESPACE}${_fa_color_reset}"
}

# ─── Lista contextos disponíveis ───
fa_list_contexts() {
  echo -e "${_fa_color_cyan}📋 Contextos kubectl disponíveis:${_fa_color_reset}"
  kubectl config get-contexts -o name | while read -r ctx; do
    if [[ "$ctx" == "$(kubectl config current-context 2>/dev/null)" ]]; then
      echo -e "  ${_fa_color_green}● ${ctx} (ativo)${_fa_color_reset}"
    else
      echo -e "  ○ ${ctx}"
    fi
  done
}

# ─── Main ───
case "${1:-status}" in
  dev|local|minikube)
    fa_use_dev
    ;;
  prod|oke|production)
    fa_use_prod
    ;;
  status|info)
    fa_show_context
    fa_list_contexts
    ;;
  *)
    echo -e "${_fa_color_red}Uso: source fa-env.sh {dev|prod|status}${_fa_color_reset}"
    echo ""
    echo "  dev   / local      → Minikube"
    echo "  prod  / oke        → Oracle OKE (produção)"
    echo "  status / info      → mostra contexto atual"
    ;;
esac
