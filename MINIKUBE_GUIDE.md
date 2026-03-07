# Farm Automation — Guia de Ambiente Local (Minikube) e Produção (OKE)

## Visão Geral

Este projeto usa dois ambientes Kubernetes:

| Ambiente | Cluster | Arquitetura | Imagens |
|----------|---------|-------------|---------|
| **DEV** | Minikube local | amd64 | Buildadas localmente (`*:local`) |
| **PROD** | Oracle OKE (arm64) | arm64 | `ghcr.io/tromanini125/*:latest` |

### Serviços

| Serviço | Porta (k8s) | Descrição |
|---------|-------------|-----------|
| `fa-admin-web` | 80 | Frontend React (nginx) |
| `fa-admin-bff` | 8080 | Backend-for-Frontend (Go) |
| `fa-auth-service` | 8080 | Autenticação + JWT (Go) |
| `fa-schedule-service` | 8080 | Agenda/Eventos (Go) |
| `fa-stock-service` | 8080 | Estoque (Go) |
| `fa-finance-service` | 8080 | Financeiro (Go) — **NOVO** |
| `fa-data-consumer` | 8086 | Consumidor RabbitMQ/IoT (Go) |

---

## Estrutura de Scripts

```
fa-scripts/
├── fa.sh                        # CLI principal (ponto de entrada)
├── fa-env.sh                    # Alterna contexto kubectl (dev/prod)
├── minikube-setup.sh            # Inicializa Minikube + infra
├── deploy-local.sh              # Build amd64 + deploy no Minikube
├── deploy-prod.sh               # Build arm64 + push + deploy no OKE
├── shutdown-local.sh            # Para serviços / Minikube
├── shutdown-prod.sh             # Scale down / delete em produção
├── create-local-dockerfiles.sh  # Gera Dockerfile.local (amd64)
├── build-and-push-arm64.sh      # Script legado de build arm64
└── minikube/
    ├── infra/
    │   ├── mongodb.yaml         # MongoDB para dev
    │   └── rabbitmq.yaml        # RabbitMQ para dev
    └── services/
        ├── fa-admin-web.yaml    # Frontend (NodePort 30000)
        ├── fa-admin-bff.yaml    # BFF (NodePort 30080)
        ├── fa-auth-service.yaml
        ├── fa-schedule-service.yaml
        ├── fa-stock-service.yaml
        ├── fa-finance-service.yaml
        └── fa-data-consumer.yaml
```

---

## Quick Start — Ambiente Local (Minikube)

### Pré-requisitos

- Docker
- Minikube (`brew install minikube` / `apt install minikube`)
- kubectl

### 1. Setup inicial (uma vez)

```bash
cd fa-scripts

# Inicializa Minikube + MongoDB + RabbitMQ
./fa.sh setup
```

Isso vai:
- Criar cluster Minikube (4 CPUs, 6GB RAM)
- Habilitar addons (ingress, metrics-server, dashboard)
- Criar namespace `farm-automation`
- Criar secrets (MongoDB, JWT, RabbitMQ)
- Deploy do MongoDB e RabbitMQ locais

### 2. Deploy dos serviços

```bash
# Tudo de uma vez
./fa.sh deploy local

# Apenas serviços específicos
./fa.sh deploy local auth bff web
```

O script vai:
1. Gerar `Dockerfile.local` para cada serviço Go (GOARCH=amd64)
2. Buildar imagens diretamente no Docker do Minikube
3. Aplicar manifests Kubernetes
4. Fazer rollout restart

### 3. Acessar os serviços

```bash
# Ver URLs
./fa.sh urls

# Se NodePort não funcionar (Docker driver no Linux)
./fa.sh tunnel
```

**URLs no Minikube:**
- Frontend: `http://<minikube-ip>:30000`
- BFF API: `http://<minikube-ip>:30080`

Se usar `minikube tunnel`:
- Frontend: `http://localhost:30000`
- BFF API: `http://localhost:30080`

### 4. Monitorar

```bash
# Status dos pods
./fa.sh status

# Logs de um serviço
./fa.sh logs auth
./fa.sh logs bff
./fa.sh logs web
```

### 5. Parar

```bash
# Remover serviços (mantém MongoDB/RabbitMQ)
./fa.sh down local

# Parar Minikube inteiro (preserva dados)
./fa.sh down local --full

# Deletar Minikube (perde tudo)
./fa.sh down local --delete
```

---

## Deploy em Produção (OKE)

### Pré-requisitos

- `docker buildx` com builder `arm-builder` configurado
- Login no GHCR: `docker login ghcr.io -u tromanini125`
- kubeconfig com contexto `farm-automation-oke`

### Deploy completo

```bash
./fa.sh deploy prod
```

Isso vai:
1. Pedir confirmação (é produção!)
2. Buildar imagens arm64 via `docker buildx`
3. Push para `ghcr.io/tromanini125/*`
4. Aplicar manifests de produção
5. Aplicar Ingress
6. Rollout restart

### Deploy de serviços específicos

```bash
./fa.sh deploy prod auth finance
```

### Apenas aplicar manifests (sem rebuild)

```bash
./fa.sh deploy prod --apply-only
```

### Desligar produção

```bash
# Scale down (replicas=0) — rápido e reversível
./fa.sh down prod

# Restaurar
./fa.sh up prod
```

---

## Alternar Contexto kubectl

```bash
# Trocar para Minikube
source fa-env.sh dev
# ou
./fa.sh env dev

# Trocar para OKE
source fa-env.sh prod
# ou
./fa.sh env prod

# Ver contexto atual
./fa.sh env status
```

> **Dica:** Use `source fa-env.sh` para que a variável `FA_ENV` fique disponível no shell.

---

## Diferenças Local vs Produção

| Aspecto | Local (Minikube) | Produção (OKE) |
|---------|------------------|-----------------|
| Arquitetura | amd64 | arm64 |
| Imagens | `*:local`, `imagePullPolicy: Never` | `ghcr.io/tromanini125/*:latest` |
| MongoDB | Pod no cluster (sem persistência) | Externo (connection string em secret) |
| RabbitMQ | Pod simples | RabbitMQ Cluster Operator |
| Ingress | NodePort (30000, 30080) | nginx-ingress + cert-manager + TLS |
| BFF API_URL | `http://localhost:30080` | `https://adminbff.romanini.net` |
| ENVIRONMENT | `development` | `production` |
| Probes | failureThreshold: 5 (tolerante) | failureThreshold: 3 |

---

## Referência de Comandos

```
./fa.sh help                    # Mostra esta ajuda
./fa.sh env {dev|prod|status}   # Alternar contexto
./fa.sh setup                   # Inicializar Minikube
./fa.sh deploy {local|prod}     # Deploy
./fa.sh down {local|prod}       # Shutdown
./fa.sh up prod                 # Restaurar produção
./fa.sh status                  # Status dos pods
./fa.sh logs <serviço>          # Logs (auth/schedule/stock/finance/data-consumer/bff/web)
./fa.sh tunnel                  # Minikube tunnel
./fa.sh urls                    # URLs de acesso
```

---

## Troubleshooting

### Pods em CrashLoopBackOff
```bash
./fa.sh logs <serviço>
kubectl describe pod -l app=<serviço> -n farm-automation
```

### Imagem não encontrada (ErrImageNeverPull)
```bash
# Verificar se Docker está apontando para Minikube
eval $(minikube docker-env)
docker images | grep local
```

### Não consegue acessar via NodePort
```bash
# Usar tunnel
./fa.sh tunnel
# Em outro terminal, acessar http://localhost:30000
```

### Contexto kubectl errado
```bash
./fa.sh env status
source fa-env.sh dev  # ou prod
```

### Rebuild de um serviço específico
```bash
./fa.sh deploy local bff
```
