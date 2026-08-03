@description('Región de despliegue.')
param location string

@description('Prefijo de nombres de recursos (empresa-proyecto-entorno).')
param resourcePrefix string

@description('Tags obligatorias aplicadas al recurso.')
param tags object

@description('Habilita la creación declarativa de asignaciones de rol RBAC sobre este Key Vault. Debe permanecer en false hasta aprobación humana explícita (ver CLAUDE.md, sección 5).')
param enableRoleAssignments bool

@description('Id principal (usuario/grupo/identidad administrada) al que se le asignaría el rol si enableRoleAssignments es true. Sin valor por defecto: si se omite y enableRoleAssignments es true, el despliegue fallará explícitamente en vez de asignar un rol a un principal implícito.')
param roleAssignmentPrincipalId string = ''

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

// Asignación de rol RBAC estrictamente condicionada al flag explícito. Con el valor por defecto
// (enableRoleAssignments = false) este recurso no se declara y, por tanto, no se crea ninguna
// asignación de rol en ningún despliegue de esta fase.
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableRoleAssignments && !empty(roleAssignmentPrincipalId)) {
  name: guid(keyVault.id, roleAssignmentPrincipalId, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    // Key Vault Secrets User (rol integrado de Azure). Este GUID es un identificador de rol
    // integrado, público y documentado por Microsoft (idéntico en cualquier tenant de Azure);
    // no es un Tenant ID ni un Subscription ID, por lo que no se considera un dato sensible.
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: roleAssignmentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultName string = keyVault.name
