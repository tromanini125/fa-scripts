#!/bin/bash

# ============================================================
# deploy-local.sh — Build imagens amd64 e deploy no Minikube
# ============================================================
# Builda todas as imagens localmente (amd64) dentro do Docker
# do Minikube e aplica os manifests.
#
# Uso:
#   ./deploy-local.sh              → build + deploy de tudo
#   ./deploy-local.sh auth bff web → apenas serviços específicos
#   ./deploy-local.sh --no-build   → só aplica manifests (sem rebuild)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FA_BASE="/home/thiago/Documents/Projetos/farm-automation"
NAMESPACE="farm-automation"

_green="\033[0;32m"
_yellow="\033[0;33m"
_cyan="\033[0;36m"
_red="\033[0;31m"
_reset="\033[0m"

# ─── Parse argumentos ───
NO_BUILD=false
SERVICES_ARG=()
for arg in "$@"; do
  if [[ "$arg" == "--no-build" ]]; then
    NO_BUILD=true
  else
    SERVICES_ARG+=("$arg")
  fi
done

ALL_SERVICES=("auth" "schedule" "stock" "finance" "data-consumer" "bff" "web")
SERVICES=("${SERVICES_ARG[@]:-${ALL_SERVICES[@]}}")

echo -e "${_cyan}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_cyan}║   Farm Automation — Deploy Local (Minikube)      ║${_reset}"
echo -e "${_cyan}╚══════════════════════════════════════════════════╝${_reset}"
echo ""

# ─── Verificar que Minikube está rodando ───
MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
if [[ "$MINIKUBE_STATUS" != "Running" ]]; then
  echo -e "${_red}❌ Minikube não está rodando. Execute primeiro: ./minikube-setup.sh${_reset}"
  exit 1
fi

# ─── Garantir contexto correto ───
CURRENT_CTX=$(kubectl config current-context 2>/dev/null)
if [[ "$CURRENT_CTX" != "minikube" ]]; then
  echo -e "${_yellow}⚠️  Contexto atual: ${CURRENT_CTX}. Trocando para minikube...${_reset}"
  kubectl config use-context minikube
fi

# ─── Configurar Docker para usar o daemon do Minikube ───
if [[ "$NO_BUILD" == false ]]; then
  echo -e "${_cyan}🐳 Configurando Docker para daemon do Minikube...${_reset}"
  eval $(minikube docker-env)
  echo -e "${_green}✅ Docker apontando para Minikube.${_reset}"
  echo ""

  # Gerar Dockerfile.local para serviços Go (amd64)
  echo -e "${_cyan}📝 Gerando Dockerfile.local (amd64 builds)...${_reset}"
  bash "${SCRIPT_DIR}/create-local-dockerfiles.sh"
  echo ""
fi

# ─── Função de build ───
build_image() {
  local SERVICE_NAME="$1"
  local SERVICE_PATH="$2"
  local IMAGE_TAG="${SERVICE_NAME}:local"
  local DOCKERFILE="${SERVICE_PATH}/Dockerfile"

  # Usar Dockerfile.local se existir, senão o padrão
  if [[ -f "${SERVICE_PATH}/Dockerfile.local" ]]; then
    DOCKERFILE="${SERVICE_PATH}/Dockerfile.local"
  fi

  echo -e "${_cyan}📦 Building ${SERVICE_NAME} (amd64)...${_reset}"
  docker build \
    --build-arg GOARCH=amd64 \
    --build-arg GOOS=linux \
    -t "${IMAGE_TAG}" \
    -f "${DOCKERFILE}" \
    "${SERVICE_PATH}"
  echo -e "${_green}✅ ${SERVICE_NAME} → ${IMAGE_TAG}${_reset}"
  echo ""
}

# ─── Build das imagens ───
if [[ "$NO_BUILD" == false ]]; then
  echo -e "${_cyan}🔨 Buildando imagens locais (amd64)...${_reset}"
  echo -e "${_cyan}📋 Serviços: ${SERVICES[*]}${_reset}"
  echo ""

  for SERVICE in "${SERVICES[@]}"; do
    case "${SERVICE}" in
      auth)
        build_image "fa-auth-service" "${FA_BASE}/fa-auth-service"
        ;;
      schedule)
        build_image "fa-schedule-service" "${FA_BASE}/fa-schedule-service"
        ;;
      stock)
        build_image "fa-stock-service" "${FA_BASE}/fa-stock-service"
        ;;
      finance)
        build_image "fa-finance-service" "${FA_BASE}/fa-finance-service"
        ;;
      data-consumer)
        build_image "fa-data-consumer" "${FA_BASE}/fa-data-consumer"
        ;;
      bff)
        build_image "fa-admin-bff" "${FA_BASE}/fa-admin-bff"
        ;;
      web)
        build_image "fa-admin-web" "${FA_BASE}/fa-admin-web"
        ;;
      *)
        echo -e "${_yellow}⚠️  Serviço desconhecido: '${SERVICE}'. Ignorando.${_reset}"
        ;;
    esac
  done
fi

# ─── Deploy dos manifests ───
echo -e "${_cyan}📡 Aplicando manifests no Minikube (namespace: ${NAMESPACE})...${_reset}"
echo ""

# Garantir namespace existe
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-auth-service.yaml"
      echo -e "  ${_green}✅ fa-auth-service${_reset}"
      ;;
    schedule)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-schedule-service.yaml"
      echo -e "  ${_green}✅ fa-schedule-service${_reset}"
      ;;
    stock)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-stock-service.yaml"
      echo -e "  ${_green}✅ fa-stock-service${_reset}"
      ;;
    finance)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-finance-service.yaml"
      echo -e "  ${_green}✅ fa-finance-service${_reset}"
      ;;
    data-consumer)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-data-consumer.yaml"
      echo -e "  ${_green}✅ fa-data-consumer${_reset}"
      ;;
    bff)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-admin-bff.yaml"
      echo -e "  ${_green}✅ fa-admin-bff${_reset}"
      ;;
    web)
      kubectl apply -f "${SCRIPT_DIR}/minikube/services/fa-admin-web.yaml"
      echo -e "  ${_green}✅ fa-admin-web${_reset}"
      ;;
  esac
done

# ─── Restart dos deployments para pegar nova imagem ───
echo ""
echo -e "${_cyan}🔄 Forçando rollout restart...${_reset}"
for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)        kubectl rollout restart deployment fa-auth-service -n "${NAMESPACE}" ;;
    schedule)    kubectl rollout restart deployment fa-schedule-service -n "${NAMESPACE}" ;;
    stock)       kubectl rollout restart deployment fa-stock-service -n "${NAMESPACE}" ;;
    finance)     kubectl rollout restart deployment fa-finance-service -n "${NAMESPACE}" ;;
    data-consumer) kubectl rollout restart deployment fa-data-consumer -n "${NAMESPACE}" ;;
    bff)         kubectl rollout restart deployment fa-admin-bff -n "${NAMESPACE}" ;;
    web)         kubectl rollout restart deployment fa-admin-web -n "${NAMESPACE}" ;;
  esac
done

# ─── Aguardar pods ficarem prontos ───
echo ""
echo -e "${_cyan}⏳ Aguardando pods ficarem prontos...${_reset}"
kubectl rollout status deployment -n "${NAMESPACE}" --timeout=180s 2>/dev/null || true

echo ""
echo -e "${_cyan}📊 Status dos pods:${_reset}"
kubectl get pods -n "${NAMESPACE}" -o wide

# ─── Mostrar URLs de acesso ───
echo ""
MINIKUBE_IP=$(minikube ip)
echo -e "${_green}╔══════════════════════════════════════════════════╗${_reset}"
echo -e "${_green}║   Deploy local concluído!                        ║${_reset}"
echo -e "${_green}╠══════════════════════════════════════════════════╣${_reset}"
echo -e "${_green}║                                                  ║${_reset}"
echo -e "${_green}║   🌐 Frontend: ${_yellow}http://${MINIKUBE_IP}:30000${_green}          ║${_reset}"
echo -e "${_green}║   🔌 BFF API:  ${_yellow}http://${MINIKUBE_IP}:30080${_green}          ║${_reset}"
echo -e "${_green}║                                                  ║${_reset}"
echo -e "${_green}║   Ou via minikube service:                       ║${_reset}"
echo -e "${_green}║   minikube service fa-admin-web -n farm-automation║${_reset}"
echo -e "${_green}║   minikube service fa-admin-bff -n farm-automation║${_reset}"
echo -e "${_green}║                                                  ║${_reset}"
echo -e "${_green}╚══════════════════════════════════════════════════╝${_reset}"
