# Deploy no Kubernetes - Farm Automation

Este documento descreve como fazer o deploy das aplicações no cluster Kubernetes.

## Pré-requisitos

1. Cluster Kubernetes configurado e kubectl conectado
2. Docker instalado e configurado
3. Acesso ao GitHub Container Registry (ghcr.io)
4. Namespace `farm-automation` criado
5. Secret `fa-admin-bff-secret` com JWT_SECRET configurado
6. Secret `mongodb-secret` com credenciais do MongoDB configurado

## Arquitetura

### Serviços Backend (porta 8080)
- **fa-auth-service**: Serviço de autenticação e gerenciamento de usuários
- **fa-schedule-service**: Serviço de gerenciamento de agenda
- **fa-stock-service**: Serviço de gerenciamento de estoque

### BFF (porta 8080)
- **fa-admin-bff**: Backend for Frontend que orquestra chamadas aos serviços

### Frontend (porta 80)
- **fa-admin-web**: Interface web React/Vite

## Secrets Necessários

### 1. MongoDB Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: farm-automation
type: Opaque
stringData:
  username: "fa-user"
  password: "uv7gWjde6Pqs0hJM"
  mongodb-uri: "mongodb+srv://fa-user:uv7gWjde6Pqs0hJM@psicoadm.qv4tpmf.mongodb.net/?appName=psicoAdm"
```

### 2. JWT Secret (já existente)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: fa-admin-bff-secret
  namespace: farm-automation
type: Opaque
stringData:
  JWT_SECRET: "your-super-secret-jwt-key-change-this-in-production"
```

### 3. GitHub Container Registry Secret (para pull de imagens)
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=tromanini125 \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  --namespace=farm-automation
```

## Processo de Deploy

### 1. Build e Push das Imagens Docker

```bash
# Fazer login no GitHub Container Registry
docker login ghcr.io -u tromanini125

# Executar o script de build e push
cd /home/thiago/Documents/Projetos/farm-automation/fa-scripts
./build-and-push-images.sh
```

### 2. Aplicar Secrets

```bash
# Aplicar secret do MongoDB
kubectl apply -f /home/thiago/Documents/Projetos/fa-kubernetes-cluster/secrets/mongodb-secret.yaml
```

### 3. Deploy dos Serviços Backend

```bash
# Deploy do auth-service
kubectl apply -f /home/thiago/Documents/Projetos/farm-automation/fa-auth-service/k8s/deployment-k8s.yaml

# Deploy do schedule-service
kubectl apply -f /home/thiago/Documents/Projetos/farm-automation/fa-schedule-service/k8s/deployment-k8s.yaml

# Deploy do stock-service
kubectl apply -f /home/thiago/Documents/Projetos/farm-automation/fa-stock-service/k8s/deployment-k8s.yaml
```

### 4. Deploy do BFF e Frontend

```bash
# Deploy do BFF
kubectl apply -f /home/thiago/Documents/Projetos/farm-automation/fa-admin-bff/k8s/deployment.yaml

# Deploy do Frontend
kubectl apply -f /home/thiago/Documents/Projetos/farm-automation/fa-admin-web/k8s/deployment.yaml
```

### 5. Configurar Ingress

```bash
# Aplicar regras de Ingress
kubectl apply -f /home/thiago/Documents/Projetos/fa-kubernetes-cluster/nginx/farm-automation-ingress.yaml
```

## Verificação do Deploy

```bash
# Verificar pods
kubectl get pods -n farm-automation

# Verificar services
kubectl get svc -n farm-automation

# Verificar ingress
kubectl get ingress -n farm-automation

# Ver logs de um pod específico
kubectl logs -f -n farm-automation <pod-name>

# Verificar eventos
kubectl get events -n farm-automation --sort-by='.lastTimestamp'
```

## URLs de Acesso

- **Frontend**: https://admin.romanini.net
- **BFF API**: https://adminbff.romanini.net

## Comunicação entre Serviços

O BFF se comunica com os serviços backend usando DNS interno do Kubernetes:

- `http://fa-auth-service:8080`
- `http://fa-schedule-service:8080`
- `http://fa-stock-service:8080`

## Variáveis de Ambiente

### Auth Service
- `MONGO_URI`: URI de conexão do MongoDB (do secret)
- `MONGO_DATABASE`: farm_automation
- `JWT_SECRET`: Chave secreta JWT (do secret fa-admin-bff-secret)
- `SERVER_PORT`: 8080

### Schedule Service
- `MONGODB_URI`: URI de conexão do MongoDB (do secret)
- `MONGODB_DATABASE`: farm_automation_schedule
- `JWT_SECRET`: Chave secreta JWT (do secret fa-admin-bff-secret)
- `PORT`: 8080

### Stock Service
- `MONGODB_URI`: URI de conexão do MongoDB (do secret)
- `MONGODB_DATABASE`: farm_automation_stock
- `JWT_SECRET`: Chave secreta JWT (do secret fa-admin-bff-secret)
- `PORT`: 8080

### BFF
- `PORT`: 8080
- `ENVIRONMENT`: production
- `JWT_SECRET`: Chave secreta JWT (do secret)
- `AUTH_SERVICE_URL`: http://fa-auth-service:8080
- `SCHEDULE_SERVICE_URL`: http://fa-schedule-service:8080
- `STOCK_SERVICE_URL`: http://fa-stock-service:8080

### Frontend
- `VITE_API_URL`: https://adminbff.romanini.net
- `VITE_APP_NAME`: Farm Automation Admin

## Rollback

```bash
# Verificar histórico de rollout
kubectl rollout history deployment/<deployment-name> -n farm-automation

# Fazer rollback para versão anterior
kubectl rollout undo deployment/<deployment-name> -n farm-automation

# Fazer rollback para versão específica
kubectl rollout undo deployment/<deployment-name> --to-revision=<revision> -n farm-automation
```

## Troubleshooting

### Pods em estado Pending
```bash
# Verificar eventos do pod
kubectl describe pod <pod-name> -n farm-automation

# Verificar recursos disponíveis
kubectl top nodes
kubectl describe nodes
```

### Pods em estado ImagePullBackOff
```bash
# Verificar se as imagens existem no registry
# Verificar se o secret ghcr-secret está configurado corretamente
kubectl get secret ghcr-secret -n farm-automation
```

### Pods em estado CrashLoopBackOff
```bash
# Ver logs do pod
kubectl logs <pod-name> -n farm-automation

# Ver logs anteriores (se o pod já reiniciou)
kubectl logs <pod-name> -n farm-automation --previous
```

## Notas Importantes

1. **Desenvolvimento Local**: Os arquivos `deployment.yaml` originais permanecem inalterados para não impactar o desenvolvimento local. Os novos arquivos `deployment-k8s.yaml` são usados apenas para deploy no cluster.

2. **Recursos**: Os pods foram configurados com recursos reduzidos (CPU: 50m-200m, Memory: 64Mi-128Mi) para otimizar o uso do cluster.

3. **Réplicas**: Cada serviço backend está configurado com 1 réplica. O BFF e frontend mantêm 2 réplicas para alta disponibilidade.

4. **Health Checks**: Todos os serviços possuem probes de liveness e readiness configuradas no endpoint `/health`.

5. **Monitoramento**: Todos os serviços possuem annotations para scraping de métricas pelo Prometheus.
