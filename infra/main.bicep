targetScope = 'subscription'

@description('Nombre del entorno.')
@allowed(['dev'])
param environment string = 'dev'

@description('Región principal de despliegue (ver CLAUDE.md, sección 5).')
param primaryLocation string = 'eastus2'

@description('Región alterna documentada (no usada por defecto en este archivo; disponible para conmutación manual futura).')
param fallbackLocation string = 'centralus'

@description('Nombre corto del proyecto, usado como prefijo de recursos.')
param projectName string = 'centinela'

@description('Nombre corto de la empresa ficticia de referencia, usado como prefijo de recursos.')
param companyName string = 'novacasa'

@description('Presupuesto mensual máximo en USD para este entorno (límite absoluto del proyecto: ver CLAUDE.md, sección 5).')
param monthlyBudgetUsd int = 50

@description('Días de retención de logs en Log Analytics.')
param retentionDays int = 30

@description('Habilita recursos de Microsoft Foundry. Debe permanecer en false hasta validación de disponibilidad y aprobación humana explícita de un modelo de IA (ver CLAUDE.md, sección 7).')
param enableFoundry bool = false

@description('Habilita recursos de Azure AI Search. Debe permanecer en false hasta autorización explícita.')
param enableAiSearch bool = false

@description('Usuario administrador del servidor lógico de Azure SQL. No tiene valor por defecto: debe suministrarse en tiempo de validación, nunca queda registrado en el archivo de parámetros.')
param sqlAdministratorLogin string

@secure()
@description('Contraseña del administrador de Azure SQL. Valor efímero solo en memoria para validate/what-if de esta fase; nunca se guarda, nunca se muestra, nunca se usa para crear el recurso real.')
param sqlAdministratorPassword string

var resourcePrefix = '${companyName}-${projectName}-${environment}'
var resourceGroupName = 'rg-${resourcePrefix}'

var tags = {
  project: 'centinela'
  company: companyName
  environment: environment
  managedBy: 'bicep'
  costCenter: 'hackathon'
  budgetUsd: string(monthlyBudgetUsd)
}

module resourceGroupModule 'modules/resource-group.bicep' = {
  name: 'resourceGroupDeployment'
  params: {
    name: resourceGroupName
    location: primaryLocation
    tags: tags
  }
}

// Bicep exige que "scope" se pueda calcular al inicio del despliegue (BCP120): no admite una
// referencia a resourceGroupModule.outputs.resourceGroupName (valor conocido solo tras desplegar
// el módulo). Por eso el scope sigue usando la variable resourceGroupName, y la dependencia sobre
// resourceGroupModule se declara explícitamente con dependsOn en cada módulo de resource-group
// scope, para que Azure garantice que el resource group existe antes de estos nested deployments.
module monitoringModule 'modules/monitoring.bicep' = {
  name: 'monitoringDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
    retentionDays: retentionDays
  }
}

module storageModule 'modules/storage.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module keyVaultModule 'modules/key-vault.bicep' = {
  name: 'keyVaultDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module appServiceModule 'modules/app-service.bicep' = {
  name: 'appServiceDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
    applicationInsightsConnectionString: monitoringModule.outputs.applicationInsightsConnectionString
  }
}

module sqlModule 'modules/sql.bicep' = {
  name: 'sqlDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
  }
}

@description('Estado documentado de componentes de IA opcionales. Ambos permanecen deshabilitados en la Fase 03: ningún recurso de Foundry o AI Search se declara como activo.')
output aiComponentsStatus object = {
  foundryEnabled: enableFoundry
  aiSearchEnabled: enableAiSearch
  note: 'Componentes de IA deshabilitados en Fase 03; sujetos a validación de disponibilidad y aprobación humana explícita antes de habilitarse (ver CLAUDE.md, sección 7).'
}

@description('Regiones documentadas del proyecto. fallbackLocation no se usa por defecto en este archivo; queda disponible para una conmutación manual futura si primaryLocation no tuviera disponibilidad de algún SKU.')
output regionsStatus object = {
  primaryLocation: primaryLocation
  fallbackLocation: fallbackLocation
}

output resourceGroupName string = resourceGroupModule.outputs.resourceGroupName
output storageAccountName string = storageModule.outputs.storageAccountName
output keyVaultName string = keyVaultModule.outputs.keyVaultName
output webAppName string = appServiceModule.outputs.webAppName
output sqlServerName string = sqlModule.outputs.sqlServerName
output sqlDatabaseName string = sqlModule.outputs.sqlDatabaseName
