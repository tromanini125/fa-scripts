# Farm Automation - Scripts de Gerenciamento

Scripts para facilitar o gerenciamento de todas as aplicações do Farm Automation.

## 📋 Pré-requisitos

- Docker instalado e rodando
- Go 1.21+ instalado
- Node.js 18+ e npm instalados
- Bash shell (Linux/Mac ou WSL no Windows)

## 🚀 Scripts Disponíveis

### 1. `start-all.sh` - Iniciar Tudo

Inicia todos os serviços necessários automaticamente:
- MongoDB (Docker container)
- Backend (fa-auth-service)
- Frontend (fa-admin-web)

```bash
./start-all.sh
```

**O que o script faz:**
1. Verifica se as dependências estão instaladas
2. Inicia MongoDB no Docker com usuário/senha padrão
3. Compila e inicia o backend
4. Cria usuário admin padrão
5. Instala dependências e inicia o frontend
6. Exibe resumo com URLs e credenciais

**Credenciais padrão:**
- Email: `admin@farmautomation.com`
- Senha: `Admin@123`

**URLs dos serviços:**
- Frontend: http://localhost:5173
- Backend: http://localhost:8080
- MongoDB: mongodb://admin:admin123@localhost:27017

---

### 2. `stop-all.sh` - Parar Tudo

Para todos os serviços preservando os dados:

```bash
./stop-all.sh
```

**O que o script faz:**
1. Para o frontend (processo Node.js)
2. Para o backend (processo Go)
3. Para o container MongoDB (dados são preservados)

**Nota:** Os dados do MongoDB são preservados em um volume Docker e estarão disponíveis no próximo start.

---

### 3. `reset-all.sh` - Resetar Tudo

Remove TODOS os dados e reseta o ambiente:

```bash
./reset-all.sh
```

**⚠️ ATENÇÃO:** Este comando é DESTRUTIVO!

**O que o script faz:**
1. Para todos os serviços
2. Remove o container MongoDB
3. Remove o volume com TODOS os dados do banco
4. Limpa todos os logs
5. Remove binários compilados

Use este script quando quiser começar do zero.

---

### 4. `status.sh` - Verificar Status

Verifica o status de todos os serviços:

```bash
./status.sh
```

**Informações exibidas:**
- Status do MongoDB (rodando/parado)
- Status do Backend (rodando/parado, PID, health check)
- Status do Frontend (rodando/parado, PID, health check)
- URLs de acesso
- Credenciais de login

---

### 5. `logs.sh` - Visualizar Logs

Visualiza logs dos serviços em tempo real:

```bash
./logs.sh
```

**Opções disponíveis:**
1. Logs do Backend
2. Logs do Frontend
3. Logs do MongoDB
4. Todos os logs simultaneamente

Pressione `Ctrl+C` para sair da visualização.

---

## 📁 Estrutura de Arquivos Gerados

```
farm-automation/
├── fa-scripts/               # Scripts de gerenciamento
│   ├── start-all.sh          # Iniciar todos os serviços
│   ├── stop-all.sh           # Parar todos os serviços
│   ├── reset-all.sh          # Resetar tudo (remove dados)
│   ├── status.sh             # Verificar status
│   ├── logs.sh               # Visualizar logs
│   └── README.md             # Este arquivo
├── fa-auth-service/
│   ├── .env              # Configurações do backend (criado automaticamente)
│   ├── .backend.pid      # PID do processo backend
│   ├── bin/
│   │   └── fa-auth-service  # Binário compilado
│   └── logs/
│       └── backend.log   # Logs do backend
└── fa-admin-web/
    ├── .env              # Configurações do frontend (criado automaticamente)
    ├── .frontend.pid     # PID do processo frontend
    └── logs/
        └── frontend.log  # Logs do frontend
```

---

## 🔧 Fluxo de Trabalho Recomendado

### Primeira vez:
```bash
# 1. Entrar na pasta de scripts
cd fa-scripts

# 2. Dar permissão de execução aos scripts (já feito)
chmod +x *.sh

# 3. Iniciar tudo
./start-all.sh

# 4. Acessar http://localhost:5173
# Login: admin@farmautomation.com / Admin@123
```

### Desenvolvimento diário:
```bash
# Entrar na pasta de scripts
cd fa-scripts

# Iniciar trabalho
./start-all.sh

# Verificar se tudo está rodando
./status.sh

# Durante desenvolvimento, ver logs
./logs.sh

# Ao finalizar o dia
./stop-all.sh
```

### Resetar quando necessário:
```bash
# Se precisar começar do zero (remove todos os dados!)
./reset-all.sh
./start-all.sh
```

---

## 🐛 Troubleshooting

### MongoDB não inicia
```bash
# Verificar se já existe um container
docker ps -a | grep mongodb

# Remover container antigo
docker rm -f fa-mongodb

# Tentar novamente
./start-all.sh
```

### Backend não compila
```bash
cd fa-auth-service

# Limpar cache do Go
go clean -cache

# Baixar dependências novamente
go mod download

# Compilar manualmente
go build -o bin/fa-auth-service cmd/api/main.go
```

### Frontend não inicia
```bash
cd fa-admin-web

# Remover node_modules e reinstalar
rm -rf node_modules package-lock.json
npm install

# Iniciar manualmente
npm run dev
```

### Porta já em uso
```bash
# Verificar processos nas portas
lsof -i :27017  # MongoDB
lsof -i :8080   # Backend
lsof -i :5173   # Frontend

# Matar processo específico
kill -9 <PID>

# Ou parar tudo e tentar novamente
./stop-all.sh
./start-all.sh
```

### Ver logs detalhados
```bash
# Backend
tail -f fa-auth-service/logs/backend.log

# Frontend
tail -f fa-admin-web/logs/frontend.log

# MongoDB
docker logs -f fa-mongodb
```

---

## 📊 Monitoramento

### Verificar saúde do backend:
```bash
curl http://localhost:8080/health
```

Resposta esperada:
```json
{
  "status": "ok",
  "timestamp": "2026-01-22T..."
}
```

### Conectar no MongoDB:
```bash
# Usando Docker
docker exec -it fa-mongodb mongosh -u admin -p admin123 --authenticationDatabase admin

# Comandos úteis no mongosh:
show dbs
use farm_automation
show collections
db.users.find().pretty()
```

---

## 🔒 Segurança

### Credenciais Padrão

**MongoDB:**
- Usuário: `admin`
- Senha: `admin123`
- Database: `farm_automation`

**Aplicação:**
- Email: `admin@farmautomation.com`
- Senha: `Admin@123`

**⚠️ IMPORTANTE:**
- Estas são credenciais de DESENVOLVIMENTO
- NUNCA use em produção
- Altere as senhas antes de fazer deploy

### Variáveis de Ambiente

Os scripts criam automaticamente os arquivos `.env`:

**Backend (.env):**
```env
MONGO_URI=mongodb://admin:admin123@localhost:27017/farm_automation?authSource=admin
JWT_SECRET=farm-automation-super-secret-key-change-in-production-2026
```

**Frontend (.env):**
```env
VITE_API_URL=http://localhost:8080/api/v1
```

---

## 📝 Logs

Todos os logs são salvos na pasta `logs/` de cada aplicação:

- `fa-auth-service/logs/backend.log` - Logs do backend
- `fa-admin-web/logs/frontend.log` - Logs do frontend

Use o script `./logs.sh` para visualização conveniente.

---

## 🎯 Próximos Passos

Depois de iniciar tudo com sucesso:

1. **Fazer Login**
   - Acesse: http://localhost:5173
   - Use: admin@farmautomation.com / Admin@123

2. **Testar Funcionalidades**
   - Criar novos usuários (menu Usuários - apenas admin)
   - Alterar senha (Perfil > Alterar Senha)
   - Logout e login com novo usuário
   - Testar proteção de rotas

3. **Documentação Adicional**
   - `fa-auth-service/README.md` - Documentação do backend
   - `fa-auth-service/ARCHITECTURE.md` - Arquitetura hexagonal
   - `fa-admin-web/INTEGRATION.md` - Integração frontend-backend
   - `fa-admin-web/TESTING_GUIDE.md` - Guia de testes

---

## 🤝 Contribuindo

Para adicionar novos serviços aos scripts:

1. Edite `start-all.sh` para incluir inicialização
2. Edite `stop-all.sh` para incluir parada
3. Edite `status.sh` para incluir verificação
4. Atualize este README

---

## 📞 Suporte

Se encontrar problemas:

1. Execute `./status.sh` para diagnóstico
2. Verifique logs com `./logs.sh`
3. Tente resetar com `./reset-all.sh` e `./start-all.sh`
4. Consulte a seção de Troubleshooting acima

---

**Desenvolvido para Farm Automation** 🌱
