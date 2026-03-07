#!/bin/bash

# ============================================================
# fa.sh — Comando principal do Farm Automation
# ============================================================
# Ponto de entrada unificado para todas as operações.
#
# Uso:
#   ./fa.sh env dev          → trocar para Minikube
#   ./fa.sh env prod         → trocar para OKE
#   ./fa.sh env status       → ver contexto atual
#
#   ./fa.sh setup            → inicializar Minikube
#   ./fa.sh deploy local     → build + deploy no Minikube
#   ./fa.sh deploy prod      → build + deploy no OKE
#
#   ./fa.sh down local       → parar serviços no Minikube
#   ./fa.sh down prod        → scale down produção
#   ./fa.sh up prod          → restaurar produção
#
#   ./fa.sh status           → status dos pods no contexto atual
#   ./fa.sh logs <service>   → logs de um serviço
#   ./fa.sh tunnel           → abrir minikube tunnel (NodePort access)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="farm-automation"

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_bold="\033[1m"
_dim="\033[2m"
_reset="\033[0m"

show_help() {
  echo -e "${_cyan}${_bold}"
  echo "  ╔═══════════════════════════════════════════════╗"
  echo "  ║        🌾  Farm Automation CLI  🌾            ║"
  echo "  ╚═══════════════════════════════════════════════╝"
  echo ""
  echo -e "${_reset}${_bold}  AMBIENTE:${_reset}"
  echo -e "    ${_green}fa.sh env dev${_reset}              Trocar para Minikube"
  echo -e "    ${_green}fa.sh env prod${_reset}             Trocar para OKE"
  echo -e "    ${_green}fa.sh env status${_reset}           Ver contexto atual"
  echo ""
  echo -e "${_bold}  SETUP:${_reset}"
  echo -e "    ${_green}fa.sh setup${_reset}                Inicializar Minikube + infra"
  echo ""
  echo -e "${_bold}  DEPLOY:${_reset}"
  echo -e "    ${_green}fa.sh deploy local${_reset}         Build amd64 + deploy Minikube"
  echo -e "    ${_green}fa.sh deploy local auth bff${_reset} Deploy serviços específicos"
  echo -e "    ${_green}fa.sh deploy prod${_reset}          Build arm64 + push + deploy OKE"
  echo -e "    ${_green}fa.sh deploy prod --apply-only${_reset} Só aplicar manifests em prod"
  echo ""
  echo -e "${_bold}  SHUTDOWN:${_reset}"
  echo -e "    ${_green}fa.sh down local${_reset}           Remover serviços do Minikube"
  echo -e "    ${_green}fa.sh down local --full${_reset}    Parar Minikube inteiro"
  echo -e "    ${_green}fa.sh down prod${_reset}            Scale down produção (replicas=0)"
  echo -e "    ${_green}fa.sh up prod${_reset}              Restaurar produção (replicas=1)"
  echo ""
  echo -e "${_bold}  MONITORAMENTO:${_reset}"
  echo -e "    ${_green}fa.sh status${_reset}               Status dos pods (contexto atual)"
  echo -e "    ${_green}fa.sh logs <service>${_reset}       Logs de um serviço"
  echo -e "    ${_green}fa.sh tunnel${_reset}               Abrir minikube tunnel"
  echo -e "    ${_green}fa.sh urls${_reset}                 Mostrar URLs de acesso"
  echo ""
  echo -e "${_dim}  Serviços válidos: auth, schedule, stock, finance, data-consumer, bff, web${_reset}"
  echo ""
}

# ─── Mapear nome curto → nome do deployment ───
resolve_deployment() {
  case "$1" in
    auth)          echo "fa-auth-service" ;;
    schedule)      echo "fa-schedule-service" ;;
    stock)         echo "fa-stock-service" ;;
    finance)       echo "fa-finance-service" ;;
    data-consumer) echo "fa-data-consumer" ;;
    bff)           echo "fa-admin-bff" ;;
    web)           echo "fa-admin-web" ;;
    *)             echo "$1" ;;
  esac
}

CMD="${1:-help}"
shift 2>/dev/null || true

case "$CMD" in
  # ─── AMBIENTE ───
  env|context)
    source "${SCRIPT_DIR}/fa-env.sh" "${1:-status}"
    ;;

  # ─── SETUP ───
  setup|init)
    bash "${SCRIPT_DIR}/minikube-setup.sh"
    ;;

  # ─── DEPLOY ───
  deploy)
    TARGET="${1:-local}"
    shift 2>/dev/null || true
    case "$TARGET" in
      local|dev|minikube)
        bash "${SCRIPT_DIR}/deploy-local.sh" "$@"
        ;;
      prod|oke|production)
        bash "${SCRIPT_DIR}/deploy-prod.sh" "$@"
        ;;
      *)
        echo -e "${_red}Uso: fa.sh deploy {local|prod} [serviços...]${_reset}"
        exit 1
        ;;
    esac
    ;;

  # ─── SHUTDOWN ───
  down|stop|shutdown)
    TARGET="${1:-local}"
    shift 2>/dev/null || true
    case "$TARGET" in
      local|dev|minikube)
        bash "${SCRIPT_DIR}/shutdown-local.sh" "$@"
        ;;
      prod|oke|production)
        bash "${SCRIPT_DIR}/shutdown-prod.sh" "$@"
        ;;
      *)
        echo -e "${_red}Uso: fa.sh down {local|prod}${_reset}"
        exit 1
        ;;
    esac
    ;;

  # ─── RESUME PROD ───
  up|resume)
    TARGET="${1:-prod}"
    bash "${SCRIPT_DIR}/shutdown-prod.sh" --resume
    ;;

  # ─── STATUS ───
  status|pods)
    echo -e "${_cyan}📊 Pods no namespace '${NAMESPACE}':${_reset}"
    echo ""
    kubectl get pods -n "${NAMESPACE}" -o wide 2>/dev/null || echo "(nenhum pod encontrado)"
    echo ""
    echo -e "${_cyan}📊 Services:${_reset}"
    kubectl get svc -n "${NAMESPACE}" 2>/dev/null || true
    ;;

  # ─── LOGS ───
  logs|log)
    SERVICE="${1:?Especifique o serviço: auth, schedule, stock, finance, data-consumer, bff, web}"
    DEP_NAME=$(resolve_deployment "$SERVICE")
    echo -e "${_cyan}📋 Logs de ${DEP_NAME}:${_reset}"
    kubectl logs -f deployment/"${DEP_NAME}" -n "${NAMESPACE}" --tail=100
    ;;

  # ─── TUNNEL ───
  tunnel)
    echo -e "${_cyan}🔗 Abrindo minikube tunnel (requer sudo)...${_reset}"
    echo -e "${_yellow}   Frontend: http://localhost:30000${_reset}"
    echo -e "${_yellow}   BFF API:  http://localhost:30080${_reset}"
    echo ""
    minikube tunnel
    ;;

  # ─── URLS ───
  urls|url)
    CTX=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ "$CTX" == "minikube" ]]; then
      MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "???")
      echo -e "${_cyan}🌐 URLs Minikube:${_reset}"
      echo -e "   Frontend: ${_yellow}http://${MINIKUBE_IP}:30000${_reset}"
      echo -e "   BFF API:  ${_yellow}http://${MINIKUBE_IP}:30080${_reset}"
      echo ""
      echo -e "${_dim}   Se NodePort não funcionar, use: ./fa.sh tunnel${_reset}"
    else
      echo -e "${_cyan}🌐 URLs Produção:${_reset}"
      echo -e "   Frontend: ${_yellow}https://admin.romanini.net${_reset}"
      echo -e "   BFF API:  ${_yellow}https://adminbff.romanini.net${_reset}"
    fi
    ;;

  # ─── HELP ───
  help|--help|-h|"")
    show_help
    ;;

  *)
    echo -e "${_red}Comando desconhecido: '${CMD}'${_reset}"
    echo ""
    show_help
    exit 1
    ;;
esac
