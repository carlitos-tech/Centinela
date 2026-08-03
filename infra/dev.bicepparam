using 'main.bicep'

param environment = 'dev'
param primaryLocation = 'eastus2'
param fallbackLocation = 'centralus'
param projectName = 'centinela'
param companyName = 'novacasa'
param monthlyBudgetUsd = 50
param retentionDays = 30
param enableFoundry = false
param enableAiSearch = false

// sqlAdministratorLogin y sqlAdministratorPassword se leen de variables de entorno efímeras
// (readEnvironmentVariable) en vez de tener un valor literal aquí: un archivo .bicepparam con
// `using` exige una asignación para todo parámetro sin valor por defecto (BCP258), pero
// readEnvironmentVariable() no incrusta ningún secreto en el archivo versionado — el valor real
// solo existe en el entorno del proceso que ejecuta validate/what-if (ver infra/scripts), nunca
// en disco ni en este archivo.
param sqlAdministratorLogin = readEnvironmentVariable('CENTINELA_SQL_ADMIN_LOGIN')
param sqlAdministratorPassword = readEnvironmentVariable('CENTINELA_SQL_ADMIN_PASSWORD')
