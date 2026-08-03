targetScope = 'subscription'

@description('Nombre del Resource Group de DEV.')
param name string

@description('Región principal de despliegue (East US 2).')
param location string

@description('Tags obligatorias aplicadas al Resource Group.')
param tags object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: name
  location: location
  tags: tags
}

output resourceGroupName string = resourceGroup.name
