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
ALL_SERVICES=("auth" "schedule" "stock" "finance" "notification" "data-consumer" "bff" "web" "gateway")
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

apply_ingress_with_retry() {
  local manifest_path="$1"
  local attempts=3
  local wait_seconds=5

  for attempt in $(seq 1 "${attempts}"); do
    if kubectl apply -f "${manifest_path}"; then
      echo "  ✅ ingress aplicado"
      return 0
    fi

    echo "  ⚠️  falha ao aplicar ingress (tentativa ${attempt}/${attempts})"
    if [[ "${attempt}" -lt "${attempts}" ]]; then
      echo "  ↻ tentando novamente em ${wait_seconds}s..."
      sleep "${wait_seconds}"
    fi
  done

  echo "  ❌ não foi possível aplicar o ingress após ${attempts} tentativas"
  return 1
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
    data-consumer)
      build_and_push "fa-data-consumer" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-data-consumer"
      ;;
    bff)
      build_and_push "fa-admin-bff" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-admin-bff"
      ;;
    web)
      build_and_push "fa-admin-web" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-admin-web"
      ;;
    gateway)
      build_and_push "fa-gateway" \
        "/home/thiago/Documents/Projetos/farm-automation/fa-gateway"
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
      data-consumer)
        kubectl apply -f "${K8S_BASE}/fa-data-consumer/k8s/deployment.yaml"
        echo "  ✅ fa-data-consumer aplicado"
        ;;
      bff)
        kubectl apply -f "${K8S_BASE}/fa-admin-bff/k8s/deployment.yaml"
        echo "  ✅ fa-admin-bff aplicado"
        ;;
      web)
        kubectl apply -f "${K8S_BASE}/fa-admin-web/k8s/deployment.yaml"
        echo "  ✅ fa-admin-web aplicado"
        ;;
      gateway)
        kubectl apply -f "${K8S_BASE}/fa-gateway/k8s/deployment.yaml"
        echo "  ✅ fa-gateway aplicado"
        ;;
    esac
  done

  apply_ingress_with_retry "${K8S_CLUSTER}/nginx/farm-automation-ingress.yaml"

  echo ""
  echo "🔄 Forçando rollout restart para carregar novas imagens..."
  for SERVICE in "${SERVICES[@]}"; do
    case "${SERVICE}" in
      auth) DEPLOYMENT_NAME="fa-auth-service" ;;
      schedule) DEPLOYMENT_NAME="fa-schedule-service" ;;
      stock) DEPLOYMENT_NAME="fa-stock-service" ;;
      finance) DEPLOYMENT_NAME="fa-finance-service" ;;
      notification) DEPLOYMENT_NAME="fa-notification-service" ;;
      data-consumer) DEPLOYMENT_NAME="fa-data-consumer" ;;
      bff) DEPLOYMENT_NAME="fa-admin-bff" ;;
      web) DEPLOYMENT_NAME="fa-admin-web" ;;
      gateway) DEPLOYMENT_NAME="fa-gateway" ;;
      *) continue ;;
    esac
    kubectl rollout restart deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
  done

  echo ""
  echo "⏳ Aguardando pods ficarem prontos..."
  for SERVICE in "${SERVICES[@]}"; do
    case "${SERVICE}" in
      auth) DEPLOYMENT_NAME="fa-auth-service" ;;
      schedule) DEPLOYMENT_NAME="fa-schedule-service" ;;
      stock) DEPLOYMENT_NAME="fa-stock-service" ;;
      finance) DEPLOYMENT_NAME="fa-finance-service" ;;
      notification) DEPLOYMENT_NAME="fa-notification-service" ;;
      data-consumer) DEPLOYMENT_NAME="fa-data-consumer" ;;
      bff) DEPLOYMENT_NAME="fa-admin-bff" ;;
      web) DEPLOYMENT_NAME="fa-admin-web" ;;
      gateway) DEPLOYMENT_NAME="fa-gateway" ;;
      *) continue ;;
    esac
    kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=120s || true
  done

  echo ""
  echo "📊 Status atual dos pods:"
  kubectl get pods -n "${NAMESPACE}"

else
  echo ""
  echo "ℹ️  Deploy k8s ignorado. Para aplicar manualmente:"
  echo "   kubectl rollout restart deployment -n ${NAMESPACE}"
  echo "   kubectl get pods -n ${NAMESPACE} -w"
fi
