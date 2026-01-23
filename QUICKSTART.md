# Farm Automation - Scripts de Gerenciamento

## 🚀 Início Rápido

```bash
cd fa-scripts
./start-all.sh
```

Acesse: http://localhost:5173  
Login: `admin@farmautomation.com` / `Admin@123`

## 📋 Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `start-all.sh` | Inicia MongoDB, Backend e Frontend |
| `stop-all.sh` | Para todos os serviços |
| `status.sh` | Verifica status dos serviços |
| `logs.sh` | Visualiza logs em tempo real |
| `reset-all.sh` | Remove todos os dados e reseta |

## 📖 Documentação Completa

Veja [README.md](README.md) para documentação detalhada.

## ⚙️ O que o `start-all.sh` faz?

1. ✅ Verifica dependências (Docker, Go, Node.js)
2. ✅ Inicia MongoDB no Docker
3. ✅ Compila e inicia o Backend (Go)
4. ✅ Cria usuário admin padrão
5. ✅ Instala dependências e inicia Frontend (React)

## 🛠️ Pré-requisitos

- Docker
- Go 1.21+
- Node.js 18+

---

**Tudo em um comando!** 🎯
