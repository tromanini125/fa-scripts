#!/bin/bash

# Script para fazer build e push das imagens Docker para o GitHub Container Registry
# Certifique-se de estar logado: docker login ghcr.io -u tromanini125

set -e

GITHUB_USERNAME="tromanini125"
REGISTRY="ghcr.io"

echo "🔨 Building and pushing Docker images to GitHub Container Registry..."

# fa-gateway
echo "📦 Building fa-gateway..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-gateway
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-gateway:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-gateway:latest
echo "✅ fa-gateway pushed successfully"

# fa-auth-service
echo "📦 Building fa-auth-service..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-auth-service
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-auth-service:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-auth-service:latest
echo "✅ fa-auth-service pushed successfully"

# fa-schedule-service
echo "📦 Building fa-schedule-service..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-schedule-service
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-schedule-service:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-schedule-service:latest
echo "✅ fa-schedule-service pushed successfully"

# fa-stock-service
echo "📦 Building fa-stock-service..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-stock-service
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-stock-service:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-stock-service:latest
echo "✅ fa-stock-service pushed successfully"

# fa-admin-bff
echo "📦 Building fa-admin-bff..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-admin-bff
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-admin-bff:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-admin-bff:latest
echo "✅ fa-admin-bff pushed successfully"

# fa-admin-web
echo "📦 Building fa-admin-web..."
cd /home/thiago/Documents/Projetos/farm-automation/fa-admin-web
docker build -t ${REGISTRY}/${GITHUB_USERNAME}/fa-admin-web:latest .
docker push ${REGISTRY}/${GITHUB_USERNAME}/fa-admin-web:latest
echo "✅ fa-admin-web pushed successfully"

echo ""
echo "🎉 All images built and pushed successfully!"
echo ""
echo "Next steps:"
echo "1. kubectl rollout restart deployment -n farm-automation"
echo "2. kubectl get pods -n farm-automation -w"
