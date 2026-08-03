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

@description('Habilita la regla de firewall de Azure SQL "AllowAzureServices" (0.0.0.0-0.0.0.0). Debe permanecer en false hasta necesidad concreta y aprobación humana explícita de una regla de alcance mínimo (ver CLAUDE.md, sección 5).')
param enableSqlAllowAzureServicesRule bool = false

@description('Usuario administrador del servidor lógico de Azure SQL. No tiene valor por defecto: debe suministrarse en tiempo de validación, nunca queda registrado en el archivo de parámetros.')
param sqlAdministratorLogin string

@secure()
@description('Contraseña del administrador de Azure SQL. Valor efímero solo en memoria para validate/what-if de esta fase; nunca se guarda, nunca se muestra, nunca se usa para crear el recurso real.')
param sqlAdministratorPassword string

var resourcePrefix = '${companyName}-${projectName}-${environment}'
var resourceGroupName = 'rg-${resourcePrefix}'

// Sufijo determinista y globalmente único (13 caracteres) para los recursos cuyo nombre debe ser
// único en todo Azure (Storage Account, Key Vault, Web App, servidor lógico de Azure SQL). Se
// deriva de subscription().id (función, nunca un literal embebido) y del nombre del resource
// group: reproducible para la misma suscripción + entorno, sin exponer el Subscription ID como
// texto en ningún archivo versionado. Resource Group, App Service Plan, Log Analytics y
// Application Insights mantienen nombres legibles basados solo en resourcePrefix, porque su
// unicidad requerida es dentro de la suscripción/resource group, no global.
var uniqueSuffix = uniqueString(subscription().id, resourceGroupName)

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
    uniqueSuffix: uniqueSuffix
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
    uniqueSuffix: uniqueSuffix
  }
}

// appServiceModule NO recibe ningun output de monitoringModule (Correccion short-circuit what-if,
// Fase 04): un parametro derivado de un modulo aun no desplegado (monitoringModule.outputs.*)
// impide que el motor de what-if de Azure evalue completamente el modulo dependiente, y lo excluye
// por completo del arreglo de cambios devuelto (confirmado empiricamente: el what-if reportaba
// solo 7 de los 9 recursos aprobados, faltando exactamente Microsoft.Web/serverfarms y
// Microsoft.Web/sites, pese a que az deployment sub validate aprobaba la plantilla completa). La
// conexion entre el backend y Application Insights queda diferida al despliegue posterior de la
// aplicacion (cuando ambos recursos ya existen realmente), con su propia validacion y autorizacion
// — ver seccion de documentacion del reporte de evidencia.
module appServiceModule 'modules/app-service.bicep' = {
  name: 'appServiceDeployment'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [resourceGroupModule]
  params: {
    location: primaryLocation
    resourcePrefix: resourcePrefix
    tags: tags
    uniqueSuffix: uniqueSuffix
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
    uniqueSuffix: uniqueSuffix
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    enableAllowAzureServicesFirewallRule: enableSqlAllowAzureServicesRule
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
