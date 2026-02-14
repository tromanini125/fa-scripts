// Script para corrigir o usuário admin no MongoDB
// Execute com: docker exec <container_id> mongo farm_automation --username root --password root --authenticationDatabase admin fix-admin-user.js

// Ou copie e cole no mongo shell

// Atualizar usuário admin
const result = db.users.updateOne(
  { email: "admin@farmautomation.com" },
  {
    $set: {
      active: true,
      emailVerified: true,
      updatedAt: new Date()
    }
  }
);

print("Resultado da atualização:");
printjson(result);

// Verificar se foi atualizado
const user = db.users.findOne({ email: "admin@farmautomation.com" });
print("\nUsuário após atualização:");
printjson({
  email: user.email,
  name: user.name,
  role: user.role,
  active: user.active,
  emailVerified: user.emailVerified
});
