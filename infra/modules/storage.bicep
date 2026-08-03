@description('Región de despliegue.')
param location string

@description('Prefijo de nombres de recursos (empresa-proyecto-entorno).')
param resourcePrefix string

@description('Tags obligatorias aplicadas al recurso.')
param tags object

// Los nombres de Storage Account son globalmente únicos, 3-24 caracteres, solo minúsculas y
// dígitos: se elimina cualquier guion del prefijo y se trunca a 24 caracteres. El linter no puede
// probar estáticamente una longitud mínima a partir de una interpolación de parámetros (BCP334);
// el prefijo 'st' ya garantiza en tiempo de ejecución al menos 2 caracteres más el contenido de
// resourcePrefix, que en este proyecto siempre es no vacío (companyName-projectName-environment).
var storageAccountName = take(toLower(replace('st${resourcePrefix}', '-', '')), 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
#disable-next-line BCP334
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
  }
}

// El hosting de sitio estático (contenedor `$web`) es una operación de plano de datos
// (`az storage blob service-properties update --static-website`), no un recurso ARM/Bicep
// declarativo en la API de Storage; se documenta aquí y se ejecuta, si corresponde, en una fase
// posterior de despliegue real — no se declara como recurso Bicep para evitar modelar un tipo de
// recurso inexistente.

output storageAccountName string = storageAccount.name
