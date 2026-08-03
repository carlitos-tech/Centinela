@description('Región de despliegue.')
param location string

@description('Prefijo de nombres de recursos (empresa-proyecto-entorno).')
param resourcePrefix string

@description('Tags obligatorias aplicadas a los recursos.')
param tags object

@description('Usuario administrador del servidor lógico de Azure SQL. Nunca se guarda en el archivo de parámetros.')
param sqlAdministratorLogin string

@secure()
@description('Contraseña del administrador de Azure SQL. Valor efímero solo en memoria para validate/what-if; nunca se guarda ni se muestra.')
param sqlAdministratorPassword string

@description('Sufijo determinista de 13 caracteres (uniqueString), calculado en main.bicep, para garantizar unicidad global del nombre del servidor lógico.')
param uniqueSuffix string

@description('Habilita la regla de firewall "AllowAzureServices" (0.0.0.0-0.0.0.0). Debe permanecer en false hasta que exista una necesidad concreta y aprobación humana explícita para una regla de acceso con alcance mínimo (ver CLAUDE.md, sección 5, e infra/CLAUDE.md).')
param enableAllowAzureServicesFirewallRule bool = false

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: toLower('sql-${resourcePrefix}-${uniqueSuffix}')
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Opt-in (Fase 04, Paso 7): esta regla queda deshabilitada por defecto (enableAllowAzureServicesFirewallRule = false
// en dev.bicepparam). Permitiría que otros servicios de Azure alcancen el servidor sin abrir el
// firewall a Internet en general, pero un rango 0.0.0.0-0.0.0.0 abre el servidor a *cualquier*
// recurso de Azure en *cualquier* suscripción, no solo a los de este proyecto — se prefiere no
// crear ninguna regla de firewall hasta que exista una necesidad concreta (p. ej. la Web App
// necesitando alcanzar la base de datos) y una decisión explícita sobre el alcance mínimo
// necesario. Con el flag en false, este recurso no se declara en absoluto (no aparece en
// `what-if`), en vez de crearse deshabilitado.
resource allowAzureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2024-05-01-preview' = if (enableAllowAzureServicesFirewallRule) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  parent: sqlServer
  name: 'sqldb-${resourcePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 2147483648
  }
}

output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
