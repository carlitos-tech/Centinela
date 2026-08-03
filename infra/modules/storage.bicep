@description('Región de despliegue.')
param location string

@description('Prefijo de nombres de recursos (empresa-proyecto-entorno).')
param resourcePrefix string

@description('Tags obligatorias aplicadas al recurso.')
param tags object

@description('Sufijo determinista de 13 caracteres (uniqueString), calculado en main.bicep, para garantizar unicidad global del nombre.')
param uniqueSuffix string

// Los nombres de Storage Account son globalmente únicos, 3-24 caracteres, solo minúsculas y
// dígitos. Presupuesto de longitud: 'st' (2) + namePrefix (9) + uniqueSuffix (13) = 24 exactos, de
// modo que uniqueSuffix nunca se trunca (es la garantía real de unicidad global). El linter no
// puede probar estáticamente una longitud mínima a partir de una interpolación de parámetros
// (BCP334); namePrefix + uniqueSuffix siempre producen contenido no vacío.
var namePrefix = take(toLower(replace(resourcePrefix, '-', '')), 9)
var storageAccountName = take('st${namePrefix}${uniqueSuffix}', 24)

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
    allowBlobPublicAccess: false
  }
}

// Endurecimiento (Fase 04, Paso 6): allowBlobPublicAccess=false — ningún contenedor puede
// exponerse anónimamente aunque su nivel de acceso individual se configure erróneamente después.
// No se declara ningún contenedor ni configuración de sitio estático en este módulo: la decisión
// de dónde alojar el frontend (Web App vs. Storage static website) se difiere a una fase posterior
// de despliegue real, y de habilitarse un sitio estático más adelante, requerirá una decisión
// explícita separada que reconsidere este `allowBlobPublicAccess=false` para el contenedor `$web`
// específicamente (el static website de Storage exige acceso público de lectura a ese contenedor).
// El hosting de sitio estático es, en cualquier caso, una operación de plano de datos
// (`az storage blob service-properties update --static-website`), no un recurso ARM/Bicep
// declarativo en la API de Storage.

output storageAccountName string = storageAccount.name
