param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerAppsEnvironmentName string
param containerRegistryName string
param containerRegistryHostSuffix string
param keyVaultName string
param appConfigName string
param serviceName string = 'api'
param corsAcaUrl string
param exists bool

resource apiIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

// Give the API access to KeyVault
module apiKeyVaultAccess '../core/security/keyvault-access.bicep' = {
  name: 'api-keyvault-access'
  params: {
    keyVaultName: keyVaultName
    principalId: apiIdentity.properties.principalId
  }
}

// Give the API access to App Configuration. Role assignment after both created otherwise mutual dependency.
module appConfigurationAccess '../core/security/configstore-access.bicep' = {
  name: 'app-configuration-access'
  params: {
    configStoreName: appConfiguratoin.name
    principalId: apiIdentity.properties.principalId
  }
}

module app '../core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app'
  dependsOn: [ apiKeyVaultAccess ]
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityType: 'UserAssigned'
    identityName: apiIdentity.name
    exists: exists
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    containerRegistryHostSuffix: containerRegistryHostSuffix
    containerCpuCoreCount: '1.0'
    containerMemory: '2.0Gi'
    env: [
      {
        name: 'AZURE_CLIENT_ID'
        value: apiIdentity.properties.clientId
      }
      {
        name: 'AZURE_KEY_VAULT_ENDPOINT'
        value: keyVault.properties.vaultUri
      }
      {
        name: 'AZURE_APPCONFIGURATION_ENDPOINT'
        value: appConfiguratoin.properties.endpoint
      }
      {
        name: 'API_ALLOW_ORIGINS'
        value: corsAcaUrl
      }
    ]
    targetPort: 3100
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource appConfiguratoin 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigName
}

output SERVICE_API_IDENTITY_PRINCIPAL_ID string = apiIdentity.properties.principalId
output SERVICE_API_NAME string = app.outputs.name
output SERVICE_API_URI string = app.outputs.uri
output SERVICE_API_IMAGE_NAME string = app.outputs.imageName
