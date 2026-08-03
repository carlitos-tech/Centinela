@description('Región de despliegue.')
param location string

@description('Prefijo de nombres de recursos (empresa-proyecto-entorno).')
param resourcePrefix string

@description('Tags obligatorias aplicadas al recurso.')
param tags object

var keyVaultName = take(toLower(replace('kv-${resourcePrefix}', '--', '-')), 24)

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
  }
}

// La Fase 03 no crea ninguna asignación de rol RBAC. enableRbacAuthorization=true (arriba) solo
// configura el modo de autorización del Key Vault; sin una asignación de rol, ningún principal
// tiene acceso a los secretos. La asignación declarativa de RBAC se difiere a la Fase 04, sujeta a
// aprobación humana explícita (ver CLAUDE.md, sección 5, e infra/CLAUDE.md).
output keyVaultName string = keyVault.name
