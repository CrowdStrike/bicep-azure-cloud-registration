import { LogIngestionSettings } from 'models/log-ingestion.bicep'

targetScope = 'managementGroup'

metadata name = 'CrowdStrike Falcon Cloud Security Integration'
metadata description = 'Deploys CrowdStrike Falcon Cloud Security integration for Asset Inventory and Real Time Visibility and Detection assessment'
metadata owner = 'CrowdStrike'

/*
  This Bicep template deploys CrowdStrike Falcon Cloud Security integration for
  Asset Inventory and Real Time Visibility and Detection assessment.

  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('List of Azure management group IDs to monitor. These management groups will be configured for CrowdStrike monitoring.')
param managementGroupIds array = []

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array = []

@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs.')
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

@description('List of IP addresses of Crowdstrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array = []

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string = deployment().location

@maxLength(4)
@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string = 'prod'

@description('Tags to be applied to all deployed resources. Used for resource organization and governance.')
param tags object = {
  CSTagVendor: 'Crowdstrike'
}

@maxLength(10)
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string = ''

@maxLength(10)
@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string = ''

@description('Controls whether to enable Real Time Visibility and Detection feature that provides immediate insight into security events and threats across monitored Azure resources')
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

/* Resources used across modules
1. Role assignments to the Crowdstrike's app service principal
2. Discover subscriptions of the specified management groups
*/
module assetInventory 'modules/cs-asset-inventory-mg.bicep' = {
  name: '${resourceNamePrefix}cs-inv-mg-deployment${environment}${resourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: subscriptions
    azurePrincipalId: azurePrincipalId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
  }
}

var resourceGroupName = '${resourceNamePrefix}rg-cs${environment}${resourceNameSuffix}'
module resourceGroup 'modules/common/resourceGroup.bicep' = if (shouldDeployLogIngestion) {
  name: '${resourceNamePrefix}cs-rg${environment}${resourceNameSuffix}'
  scope: subscription(csInfraSubscriptionId)

  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
  }
}

module scriptRunnerIdentity 'modules/cs-script-runner-identity-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${resourceNamePrefix}cs-script-runner-identity${environment}${resourceNameSuffix}'

  params: {
    csInfraSubscriptionId: csInfraSubscriptionId
    managementGroupIds: managementGroups
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    location: location
    tags: tags
  }

  dependsOn: [
    resourceGroup
  ]
}

module deploymentScope 'modules/cs-deployment-scope-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${resourceNamePrefix}cs-deployment-scope${environment}${resourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: subscriptions
    resourceGroupName: resourceGroupName
    scriptRunnerIdentityId: scriptRunnerIdentity.outputs.id
    csInfraSubscriptionId: csInfraSubscriptionId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    location: location
    tags: tags
  }
}

module logIngestion 'modules/cs-log-ingestion-mg.bicep' = if (shouldDeployLogIngestion) {
  name: '${resourceNamePrefix}cs-log-mg-deployment${environment}${resourceNameSuffix}'
  params: {
    managementGroupIds: managementGroups
    subscriptionIds: deploymentScope.outputs.allSubscriptions
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
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    location: location
    env: env
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

module updateRegistration 'modules/cs-update-registration-rg.bicep' = if (shouldDeployLogIngestion) {
  name: '${resourceNamePrefix}cs-update-reg-mg${environment}${resourceNameSuffix}'
  scope: az.resourceGroup(csInfraSubscriptionId, resourceGroupName)
  params: {
    falconApiFqdn: falconApiFqdn
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    activityLogEventHubId: logIngestion.outputs.activityLogEventHubId
    activityLogEventHubConsumerGroupName: logIngestion.outputs.activityLogEventHubConsumerGroupName
    entraLogEventHubId: logIngestion.outputs.entraLogEventHubId
    entraLogEventHubConsumerGroupName: logIngestion.outputs.entraLogEventHubConsumerGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    env: env
    location: location
    tags: tags
  }
}

output customReaderRoleNameForSubs array = assetInventory.outputs.customRoleNameForSubs
output customReaderRoleNameForMGs array = assetInventory.outputs.customRoleNameForMGs
output activityLogEventHubId string = shouldDeployLogIngestion ? logIngestion.outputs.activityLogEventHubId : ''
output activityLogEventHubConsumerGroupName string = shouldDeployLogIngestion
  ? logIngestion.outputs.activityLogEventHubConsumerGroupName
  : ''
output entraLogEventHubId string = shouldDeployLogIngestion ? logIngestion.outputs.entraLogEventHubId : ''
output entraLogEventHubConsumerGroupName string = shouldDeployLogIngestion
  ? logIngestion.outputs.entraLogEventHubConsumerGroupName
  : ''
