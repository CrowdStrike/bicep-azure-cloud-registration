import { LogIngestionSettings } from 'models/log-ingestion.bicep'

targetScope = 'managementGroup'

metadata name = 'CrowdStrike Falcon Cloud Security Integration'
metadata description = 'Deploys CrowdStrike Falcon Cloud Security integration for asset inventory and real-time visibility and detection assessment'
metadata owner = 'CrowdStrike'

/*
  This Bicep template deploys CrowdStrike Falcon Cloud Security integration for
  asset inventory and real-time visibility and detection assessment.

  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array = []

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array = []

@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like event hubs.')
param csInfraSubscriptionId string = ''

@description('Principal ID of the CrowdStrike application registered in Entra ID. This ID is used for role assignments and access control.')
param azurePrincipalId string

@description('Base URL of the Falcon API.')
param falconApiFqdn string = ''

@description('Client ID for the Falcon API.')
param falconClientId string = ''

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string = ''

@description('List of IP addresses of CrowdStrike Falcon service. For the IP address list for your Falcon region, refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0.')
param falconIpAddresses array = []

@description('Indicates whether this is the initial registration')
param isInitialRegistration bool = true

@description('Azure location (region) where global resources such as role definitions and event hub will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string = deployment().location

@maxLength(4)
@description('Environment label (for example, prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string = 'prod'

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object = {
  CSTagVendor: 'CrowdStrike'
}

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Controls whether to enable real-time visibility and detection, which provides immediate insight into security events and threats across monitored Azure resources.')
param enableRealTimeVisibility bool = false

@description('Configuration settings for the log ingestion module, which enables monitoring of Azure activity and Entra ID logs')
param logIngestionSettings LogIngestionSettings = {
  activityLogSettings: {
    enabled: true
    deployRemediationPolicy: true
    existingEventhub: {
      use: false
      name: ''
      namespaceName: ''
      resourceGroupName: ''
      subscriptionId: ''
      consumerGroupName: ''
    }
  }
  entraIdLogSettings: {
    enabled: true
    existingEventhub: {
      use: false
      name: ''
      namespaceName: ''
      resourceGroupName: ''
      subscriptionId: ''
      consumerGroupName: ''
    }
  }
}

// ===========================================================================
var subscriptions = union(subscriptionIds, csInfraSubscriptionId == '' ? [] : [csInfraSubscriptionId]) // remove duplicated values
var managementGroups = union(
  length(managementGroupIds) == 0 && length(subscriptionIds) == 0 ? [tenant().tenantId] : managementGroupIds,
  []
) // remove duplicated values
var environment = length(env) > 0 ? '-${env}' : env
var shouldDeployLogIngestion = enableRealTimeVisibility
var validatedFalconClientID = enableRealTimeVisibility && empty(falconClientId)
  ? fail('"falconClientId" is required when real-time visibility and detection is enabled, please specify it in parameters.bicepparam')
  : falconClientId
var validatedFalconClientSecret = enableRealTimeVisibility && empty(falconClientSecret)
  ? fail('"falconClientSecret" is required when real-time visibility and detection is enabled, please specify it to environment variable, "FALCON_CLIENT_SECRET"')
  : falconClientSecret
var validatedResourceNamePrefix = length(resourceNamePrefix) + length(resourceNameSuffix) > 10
  ? fail('Combined prefix and suffix length must not exceed 10 characters')
  : resourceNamePrefix
var validatedResourceNameSuffix = length(resourceNamePrefix) + length(resourceNameSuffix) > 10
  ? fail('Combined prefix and suffix length must not exceed 10 characters')
  : resourceNameSuffix

/* Resources used across modules
1. Role assignments to the CrowdStrike's app service principal
2. Discover subscriptions of the specified management groups
*/
module assetInventory 'modules/cs-asset-inventory-mg.bicep' = {
  name: '${validatedResourceNamePrefix}cs-inv-mg-deployment${environment}${validatedResourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: subscriptions
    azurePrincipalId: azurePrincipalId
    resourceNamePrefix: validatedResourceNamePrefix
    resourceNameSuffix: validatedResourceNameSuffix
    env: env
  }
}

var resourceGroupName = '${validatedResourceNamePrefix}rg-cs${environment}${validatedResourceNameSuffix}'
module resourceGroup 'modules/common/resourceGroup.bicep' = if (shouldDeployLogIngestion) {
  name: '${validatedResourceNamePrefix}cs-rg${environment}${validatedResourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)

  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
  }
}

module scriptRunnerIdentity 'modules/cs-script-runner-identity-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${validatedResourceNamePrefix}cs-script-runner-identity${environment}${validatedResourceNameSuffix}'

  params: {
    csInfraSubscriptionId: csInfraSubscriptionId
    managementGroupIds: managementGroups
    resourceGroupName: resourceGroupName
    resourceNamePrefix: validatedResourceNamePrefix
    resourceNameSuffix: validatedResourceNameSuffix
    env: env
    location: location
    tags: tags
  }

  dependsOn: [
    resourceGroup
  ]
}

module deploymentScope 'modules/cs-deployment-scope-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${validatedResourceNamePrefix}cs-deployment-scope${environment}${validatedResourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: subscriptions
    resourceGroupName: resourceGroupName
    scriptRunnerIdentityId: scriptRunnerIdentity!.outputs.id
    csInfraSubscriptionId: csInfraSubscriptionId
    resourceNamePrefix: validatedResourceNamePrefix
    resourceNameSuffix: validatedResourceNameSuffix
    env: env
    location: location
    tags: tags
  }
}

module logIngestion 'modules/cs-log-ingestion-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${validatedResourceNamePrefix}cs-log-mg-deployment${environment}${validatedResourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: deploymentScope!.outputs.allSubscriptions
    csInfraSubscriptionId: csInfraSubscriptionId
    resourceGroupName: resourceGroupName
    activityLogSettings: logIngestionSettings.?activityLogSettings ?? {
      enabled: true
    }
    entraIdLogSettings: logIngestionSettings.?entraIdLogSettings ?? {
      enabled: true
    }
    falconIpAddresses: falconIpAddresses
    azurePrincipalId: azurePrincipalId
    resourceNamePrefix: validatedResourceNamePrefix
    resourceNameSuffix: validatedResourceNameSuffix
    location: location
    env: env
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

module updateRegistration 'modules/cs-update-registration-rg.bicep' = if (shouldDeployLogIngestion) {
  name: '${validatedResourceNamePrefix}cs-update-reg-mg${environment}${validatedResourceNameSuffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    isInitialRegistration: isInitialRegistration
    falconApiFqdn: falconApiFqdn
    falconClientId: validatedFalconClientID
    falconClientSecret: validatedFalconClientSecret
    activityLogEventHubId: logIngestion!.outputs.activityLogEventHubId
    activityLogEventHubConsumerGroupName: logIngestion!.outputs.activityLogEventHubConsumerGroupName
    entraLogEventHubId: logIngestion!.outputs.entraLogEventHubId
    entraLogEventHubConsumerGroupName: logIngestion!.outputs.entraLogEventHubConsumerGroupName
    resourceNamePrefix: validatedResourceNamePrefix
    resourceNameSuffix: validatedResourceNameSuffix
    env: env
    location: location
    tags: tags
  }
}

output customReaderRoleNameForSubs array = assetInventory.outputs.customRoleNameForSubs
output customReaderRoleNameForMGs array = assetInventory.outputs.customRoleNameForMGs
output activityLogEventHubId string = shouldDeployLogIngestion ? logIngestion!.outputs.activityLogEventHubId : ''
output activityLogEventHubConsumerGroupName string = shouldDeployLogIngestion
  ? logIngestion!.outputs.activityLogEventHubConsumerGroupName
  : ''
output entraLogEventHubId string = shouldDeployLogIngestion ? logIngestion!.outputs.entraLogEventHubId : ''
output entraLogEventHubConsumerGroupName string = shouldDeployLogIngestion
  ? logIngestion!.outputs.entraLogEventHubConsumerGroupName
  : ''
