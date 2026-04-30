#!/bin/bash

# ============================================================
# deploy-prod.sh — Build arm64, push para GHCR e deploy no OKE
# ============================================================
# Encapsula o build-and-push-arm64.sh com confirmações de segurança
# e aplica os manifests de produção no cluster OKE.
#
# Uso:
#   ./deploy-prod.sh              → build + push + deploy de tudo
#   ./deploy-prod.sh auth bff web → apenas serviços específicos
#   ./deploy-prod.sh --apply-only → só aplica manifests (sem rebuild)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FA_BASE="/home/thiago/Documents/Projetos/farm-automation"
FA_CLUSTER="/home/thiago/Documents/Projetos/fa-kubernetes-cluster"
NAMESPACE="farm-automation"
PROD_CONTEXT="farm-automation-oke"   # ajuste se diferente
REGISTRY="ghcr.io"
GITHUB_USERNAME="tromanini125"
PLATFORM="linux/arm64"
BUILDER="arm-builder"

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_bold="\033[1m"
_reset="\033[0m"

# ─── Parse argumentos ───
APPLY_ONLY=false
SERVICES_ARG=()
for arg in "$@"; do
  if [[ "$arg" == "--apply-only" ]]; then
    APPLY_ONLY=true
  else
    SERVICES_ARG+=("$arg")
  fi
done

ALL_SERVICES=("auth" "schedule" "stock" "finance" "notification" "data-consumer" "bff" "web" "gateway")

# ─── Seleção interativa se nenhum serviço foi passado por argumento ───
if [[ ${#SERVICES_ARG[@]} -eq 0 ]]; then
  echo -e "${_red}${_bold}╔══════════════════════════════════════════════════╗${_reset}"
  echo -e "${_red}${_bold}║   ⚠️  DEPLOY DE PRODUÇÃO (OKE)                   ║${_reset}"
  echo -e "${_red}${_bold}╚══════════════════════════════════════════════════╝${_reset}"
  echo ""
  echo -e "${_cyan}Selecione os serviços para deploy:${_reset}"
  echo ""
  echo -e "  ${_bold}0)${_reset} ${_yellow}TODOS${_reset} (auth, schedule, stock, finance, data-consumer, bff, web, gateway)"
  for i in "${!ALL_SERVICES[@]}"; do
    echo -e "  ${_bold}$((i+1)))${_reset} ${ALL_SERVICES[$i]}"
  done
  echo ""
  echo -e "${_cyan}Digite os números separados por espaço (ex: 1 3 6) ou 0 para todos:${_reset}"
  read -rp "> " SELECTION

  if [[ -z "$SELECTION" ]]; then
    echo "Nenhum serviço selecionado. Abortado."
    exit 0
  fi

  for num in $SELECTION; do
    if [[ "$num" == "0" ]]; then
      SERVICES_ARG=("${ALL_SERVICES[@]}")
      break
    fi
    idx=$((num - 1))
    if [[ $idx -ge 0 && $idx -lt ${#ALL_SERVICES[@]} ]]; then
      SERVICES_ARG+=("${ALL_SERVICES[$idx]}")
    else
      echo -e "${_red}❌ Opção inválida: $num${_reset}"
      exit 1
    fi
  done

  if [[ ${#SERVICES_ARG[@]} -eq 0 ]]; then
    echo "Nenhum serviço selecionado. Abortado."
    exit 0
  fi
fi

SERVICES=("${SERVICES_ARG[@]}")

echo ""
echo -e "${_red}${_bold}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_red}${_bold}║   ⚠️  DEPLOY DE PRODUÇÃO (OKE)                   ║${_reset}"
echo -e "${_red}${_bold}╚══════════════════════════════════════════════════╝${_reset}"
echo ""
echo -e "${_cyan}📋 Serviços: ${_yellow}${SERVICES[*]}${_reset}"
echo -e "${_cyan}📋 Contexto: ${_yellow}${PROD_CONTEXT}${_reset}"
if [[ "$APPLY_ONLY" == true ]]; then
  BUILD_MODE="somente apply"
else
  BUILD_MODE="build + push + apply"
fi
echo -e "${_cyan}📋 Build:    ${_yellow}${BUILD_MODE}${_reset}"
echo ""

# ─── Confirmação de segurança ───
read -rp "🔴 Tem certeza que deseja fazer deploy em PRODUÇÃO? [s/N] " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[sS]$ ]]; then
  echo "Abortado."
  exit 0
fi

# ─── Mudar para contexto de produção ───
echo ""
echo -e "${_cyan}🔄 Alternando para contexto de produção...${_reset}"
kubectl config use-context "${PROD_CONTEXT}"
kubectl config set-context "${PROD_CONTEXT}" --namespace="${NAMESPACE}"
export FA_ENV="prod"
echo -e "${_green}✅ Contexto: ${PROD_CONTEXT}${_reset}"

# ─── Build e push das imagens arm64 ───
if [[ "$APPLY_ONLY" == false ]]; then
  echo ""
  echo -e "${_cyan}🔨 Buildando e pushando imagens arm64...${_reset}"

  # Verificar builder
  if ! docker buildx inspect "${BUILDER}" &>/dev/null; then
    echo -e "${_red}❌ Builder '${BUILDER}' não encontrado.${_reset}"
    echo "   Crie com: docker buildx create --name ${BUILDER} --platform linux/amd64,linux/arm64 --use"
    exit 1
  fi

  docker buildx use "${BUILDER}"

  build_and_push() {
    local SERVICE_NAME="$1"
    local SERVICE_PATH="$2"
    local IMAGE="${REGISTRY}/${GITHUB_USERNAME}/${SERVICE_NAME}:latest"

    echo -e "${_cyan}📦 Building ${SERVICE_NAME} (arm64)...${_reset}"
    docker buildx build \
      --platform "${PLATFORM}" \
      --builder "${BUILDER}" \
      --push \
      -t "${IMAGE}" \
      "${SERVICE_PATH}"
    echo -e "${_green}✅ ${SERVICE_NAME} → ${IMAGE}${_reset}"
    echo ""
  }

  apply_ingress_with_retry() {
    local manifest_path="$1"
    local attempts=3
    local wait_seconds=5

    for attempt in $(seq 1 "${attempts}"); do
      if kubectl apply -f "${manifest_path}"; then
        echo -e "  ${_green}✅ Ingress aplicado${_reset}"
        return 0
      fi

      echo -e "  ${_yellow}⚠️ falha ao aplicar Ingress (tentativa ${attempt}/${attempts})${_reset}"
      if [[ "${attempt}" -lt "${attempts}" ]]; then
        echo -e "  ${_cyan}↻ tentando novamente em ${wait_seconds}s...${_reset}"
        sleep "${wait_seconds}"
      fi
    done

    echo -e "  ${_red}❌ não foi possível aplicar o Ingress após ${attempts} tentativas${_reset}"
    return 1
  }

  for SERVICE in "${SERVICES[@]}"; do
    case "${SERVICE}" in
      auth)          build_and_push "fa-auth-service"         "${FA_BASE}/fa-auth-service" ;;
      schedule)      build_and_push "fa-schedule-service"     "${FA_BASE}/fa-schedule-service" ;;
      stock)         build_and_push "fa-stock-service"        "${FA_BASE}/fa-stock-service" ;;
      finance)       build_and_push "fa-finance-service"      "${FA_BASE}/fa-finance-service" ;;
      notification)  build_and_push "fa-notification-service" "${FA_BASE}/fa-notification-service" ;;
      data-consumer) build_and_push "fa-data-consumer"        "${FA_BASE}/fa-data-consumer" ;;
      bff)           build_and_push "fa-admin-bff"            "${FA_BASE}/fa-admin-bff" ;;
      web)           build_and_push "fa-admin-web"            "${FA_BASE}/fa-admin-web" ;;
      gateway)       build_and_push "fa-gateway"              "${FA_BASE}/fa-gateway" ;;
    esac
  done
fi

# ─── Apply dos manifests de produção ───
echo -e "${_cyan}📡 Aplicando manifests de produção...${_reset}"
echo ""

for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)
      kubectl apply -f "${FA_BASE}/fa-auth-service/k8s/deployment-k8s.yaml"
      echo -e "  ${_green}✅ fa-auth-service${_reset}"
      ;;
    schedule)
      kubectl apply -f "${FA_BASE}/fa-schedule-service/k8s/deployment-k8s.yaml"
      echo -e "  ${_green}✅ fa-schedule-service${_reset}"
      ;;
    stock)
      kubectl apply -f "${FA_BASE}/fa-stock-service/k8s/deployment-k8s.yaml"
      echo -e "  ${_green}✅ fa-stock-service${_reset}"
      ;;
    finance)
      kubectl apply -f "${FA_BASE}/fa-finance-service/k8s/deployment-k8s.yaml"
      echo -e "  ${_green}✅ fa-finance-service${_reset}"
      ;;
    notification)
      kubectl apply -f "${FA_BASE}/fa-notification-service/k8s/deployment.yaml"
      echo -e "  ${_green}✅ fa-notification-service${_reset}"
      ;;
    data-consumer)
      kubectl apply -f "${FA_BASE}/fa-data-consumer/k8s/deployment.yaml"
      echo -e "  ${_green}✅ fa-data-consumer${_reset}"
      ;;
    bff)
      kubectl apply -f "${FA_BASE}/fa-admin-bff/k8s/deployment.yaml"
      echo -e "  ${_green}✅ fa-admin-bff${_reset}"
      ;;
    web)
      kubectl apply -f "${FA_BASE}/fa-admin-web/k8s/deployment.yaml"
      echo -e "  ${_green}✅ fa-admin-web${_reset}"
      ;;
    gateway)
      kubectl apply -f "${FA_BASE}/fa-gateway/k8s/deployment.yaml"
      echo -e "  ${_green}✅ fa-gateway${_reset}"
      ;;
  esac
done

# ─── Ingress ───
echo ""
echo -e "${_cyan}📡 Aplicando Ingress...${_reset}"
apply_ingress_with_retry "${FA_CLUSTER}/nginx/farm-automation-ingress.yaml"

# ─── Rollout restart (apenas serviços selecionados) ───
echo ""
echo -e "${_cyan}🔄 Forçando rollout restart para carregar novas imagens...${_reset}"
for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)          DEPLOY_NAME="fa-auth-service" ;;
    schedule)      DEPLOY_NAME="fa-schedule-service" ;;
    stock)         DEPLOY_NAME="fa-stock-service" ;;
    finance)       DEPLOY_NAME="fa-finance-service" ;;
    notification)  DEPLOY_NAME="fa-notification-service" ;;
    data-consumer) DEPLOY_NAME="fa-data-consumer" ;;
    bff)           DEPLOY_NAME="fa-admin-bff" ;;
    web)           DEPLOY_NAME="fa-admin-web" ;;
    gateway)       DEPLOY_NAME="fa-gateway" ;;
    *)             continue ;;
  esac
  kubectl rollout restart deployment/"${DEPLOY_NAME}" -n "${NAMESPACE}" 2>/dev/null && \
    echo -e "  ${_green}✅ restart ${DEPLOY_NAME}${_reset}" || \
    echo -e "  ${_yellow}⚠️ deployment ${DEPLOY_NAME} não encontrado${_reset}"
done

echo ""
echo -e "${_cyan}⏳ Aguardando pods ficarem prontos...${_reset}"
for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)          DEPLOY_NAME="fa-auth-service" ;;
    schedule)      DEPLOY_NAME="fa-schedule-service" ;;
    stock)         DEPLOY_NAME="fa-stock-service" ;;
    finance)       DEPLOY_NAME="fa-finance-service" ;;
    notification)  DEPLOY_NAME="fa-notification-service" ;;
    data-consumer) DEPLOY_NAME="fa-data-consumer" ;;
    bff)           DEPLOY_NAME="fa-admin-bff" ;;
    web)           DEPLOY_NAME="fa-admin-web" ;;
    gateway)       DEPLOY_NAME="fa-gateway" ;;
    *)             continue ;;
  esac
  kubectl rollout status deployment/"${DEPLOY_NAME}" -n "${NAMESPACE}" --timeout=180s 2>/dev/null || true
done

echo ""
echo -e "${_cyan}📊 Status dos pods:${_reset}"
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
echo -e "${_green}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_green}║   ✅ Deploy de produção concluído!               ║${_reset}"
echo -e "${_green}║                                                  ║${_reset}"
echo -e "${_green}║   🌐 https://admin.romanini.net                  ║${_reset}"
echo -e "${_green}║   🔌 https://adminbff.romanini.net               ║${_reset}"
echo -e "${_green}║   🚪 https://gateway.romanini.net                ║${_reset}"
echo -e "${_green}╚══════════════════════════════════════════════════╝${_reset}"
