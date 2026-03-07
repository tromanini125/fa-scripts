#!/bin/bash

# Script para build e push das imagens Docker para arm64 (cluster Raspberry Pi / arm64)
# Usa o buildx builder 'arm-builder' com suporte a linux/arm64
#
# Pré-requisitos:
#   docker login ghcr.io -u tromanini125
#   docker buildx use arm-builder

set -e

GITHUB_USERNAME="tromanini125"
REGISTRY="ghcr.io"
PLATFORM="linux/arm64"
BUILDER="arm-builder"
NAMESPACE="farm-automation"

# Serviços a serem buildados (pode passar como argumento, ex: ./build-and-push-arm64.sh bff web)
SERVICES_ARG=("$@")
ALL_SERVICES=("auth" "schedule" "stock" "finance" "notification" "bff" "web")
SERVICES=("${SERVICES_ARG[@]:-${ALL_SERVICES[@]}}")

echo "🔨 Build e push para arm64 (${PLATFORM}) via builder '${BUILDER}'"
echo "📋 Serviços: ${SERVICES[*]}"
echo ""

# Verifica se o builder está disponível
if ! docker buildx inspect "${BUILDER}" &>/dev/null; then
  echo "❌ Builder '${BUILDER}' não encontrado."
  echo "   Crie com: docker buildx create --name ${BUILDER} --platform linux/amd64,linux/arm64 --use"
  exit 1
fi

docker buildx use "${BUILDER}"

build_and_push() {
  local SERVICE_NAME="$1"
  local SERVICE_PATH="$2"
  local IMAGE="${REGISTRY}/${GITHUB_USERNAME}/${SERVICE_NAME}:latest"

  echo "📦 Building ${SERVICE_NAME}..."
  docker buildx build \
    --platform "${PLATFORM}" \
    --builder "${BUILDER}" \
    --push \
    -t "${IMAGE}" \
    "${SERVICE_PATH}"
  echo "✅ ${SERVICE_NAME} pushed → ${IMAGE}"
  echo ""
}

for SERVICE in "${SERVICES[@]}"; do
  case "${SERVICE}" in
    auth)
      build_and_push "fa-auth-service" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-auth-service"
      ;;
    schedule)
      build_and_push "fa-schedule-service" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-schedule-service"
      ;;
    stock)
      build_and_push "fa-stock-service" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-stock-service"
      ;;
    finance)
      build_and_push "fa-finance-service" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-finance-service"
      ;;
    notification)
      build_and_push "fa-notification-service" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-notification-service"
      ;;
    bff)
      build_and_push "fa-admin-bff" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-admin-bff"
      ;;
    web)
      build_and_push "fa-admin-web" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-admin-web"
      ;;
    *)
      echo "⚠️  Serviço desconhecido: '${SERVICE}'. Ignorando."
      ;;
  esac
done

echo "🎉 Imagens arm64 enviadas com sucesso!"
echo ""

# ──────────────────────────────────────────────
# Deploy no cluster Kubernetes
# ──────────────────────────────────────────────
read -rp "🚀 Aplicar deployments no cluster Kubernetes? [s/N] " CONFIRM
if [[ "${CONFIRM}" =~ ^[sS]$ ]]; then

  K8S_BASE="/home/thiago/Documents/Projetos/farm-automation"
  K8S_CLUSTER="/home/thiago/Documents/Projetos/fa-kubernetes-cluster"

  echo ""
  echo "📡 Aplicando deployments no namespace '${NAMESPACE}'..."

  for SERVICE in "${SERVICES[@]}"; do
    case "${SERVICE}" in
      auth)
        kubectl apply -f "${K8S_BASE}/fa-auth-service/k8s/deployment-k8s.yaml"
        echo "  ✅ fa-auth-service aplicado"
        ;;
      schedule)
        kubectl apply -f "${K8S_BASE}/fa-schedule-service/k8s/deployment-k8s.yaml"
        echo "  ✅ fa-schedule-service aplicado"
        ;;
      stock)
        kubectl apply -f "${K8S_BASE}/fa-stock-service/k8s/deployment-k8s.yaml"
        echo "  ✅ fa-stock-service aplicado"
        ;;
      finance)
        kubectl apply -f "${K8S_BASE}/fa-finance-service/k8s/deployment-k8s.yaml"
        echo "  ✅ fa-finance-service aplicado"
        ;;
      notification)
        kubectl apply -f "${K8S_BASE}/fa-notification-service/k8s/deployment.yaml"
        echo "  ✅ fa-notification-service aplicado"
        ;;
      bff)
        kubectl apply -f "${K8S_BASE}/fa-admin-bff/k8s/deployment.yaml"
        echo "  ✅ fa-admin-bff aplicado"
        ;;
      web)
        kubectl apply -f "${K8S_BASE}/fa-admin-web/k8s/deployment.yaml"
        echo "  ✅ fa-admin-web aplicado"
        ;;
    esac
  done

  echo ""
  echo "🔄 Forçando rollout restart para carregar novas imagens..."
  kubectl rollout restart deployment -n "${NAMESPACE}"

  echo ""
  echo "⏳ Aguardando pods ficarem prontos..."
  kubectl rollout status deployment -n "${NAMESPACE}" --timeout=120s || true

  echo ""
  echo "📊 Status atual dos pods:"
  kubectl get pods -n "${NAMESPACE}"

else
  echo ""
  echo "ℹ️  Deploy k8s ignorado. Para aplicar manualmente:"
  echo "   kubectl rollout restart deployment -n ${NAMESPACE}"
  echo "   kubectl get pods -n ${NAMESPACE} -w"
fi
