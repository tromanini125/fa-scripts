#!/bin/bash
# Script para criar o secret do Firebase no cluster Kubernetes
#
# Pré-requisito:
#   1. Acesse https://console.firebase.google.com/project/farm-automation-6223c/settings/serviceaccounts/adminsdk
#   2. Clique em "Gerar nova chave privada"
#   3. Salve o arquivo JSON baixado como: firebase-service-account.json
#   4. Execute este script: ./setup-firebase-secret.sh firebase-service-account.json
#
# O script codifica o JSON em base64 e cria o secret no Kubernetes

set -e

NAMESPACE="farm-automation"
SECRET_NAME="fa-firebase-secret"
SERVICE_ACCOUNT_FILE="${1:-firebase-service-account.json}"

if [ ! -f "${SERVICE_ACCOUNT_FILE}" ]; then
  echo "❌ Arquivo não encontrado: ${SERVICE_ACCOUNT_FILE}"
  echo ""
  echo "Uso: $0 <path-to-firebase-service-account.json>"
  echo ""
  echo "Como obter o arquivo:"
  echo "  1. Acesse: https://console.firebase.google.com/project/farm-automation-6223c/settings/serviceaccounts/adminsdk"
  echo "  2. Clique em 'Gerar nova chave privada'"
  echo "  3. Salve o arquivo e passe o caminho para este script"
  exit 1
fi

echo "🔑 Criando secret '${SECRET_NAME}' no namespace '${NAMESPACE}'..."

# Encoda o JSON em base64 (sem quebras de linha)
ENCODED=$(cat "${SERVICE_ACCOUNT_FILE}" | base64 -w 0)

# Cria ou atualiza o secret
kubectl create secret generic "${SECRET_NAME}" \
  --from-literal=service-account-json="${ENCODED}" \
  --namespace="${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret '${SECRET_NAME}' criado/atualizado com sucesso!"
echo ""
echo "🔄 Reiniciando fa-notification-service para carregar as credenciais Firebase..."
kubectl rollout restart deployment/fa-notification-service -n "${NAMESPACE}"
kubectl rollout status deployment/fa-notification-service -n "${NAMESPACE}" --timeout=60s
echo ""
echo "📋 Verificando logs..."
kubectl logs -n "${NAMESPACE}" deployment/fa-notification-service --tail=5

