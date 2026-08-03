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

resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' = {
  name: 'sql-${resourcePrefix}'
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Permite que otros servicios de Azure (p. ej. la Web App del módulo app-service) alcancen el
// servidor sin abrir el firewall a Internet en general. Valor especial documentado por Azure SQL:
// un rango 0.0.0.0-0.0.0.0 habilita "Allow Azure services and resources to access this server".
resource allowAzureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2024-05-01-preview' = {
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
