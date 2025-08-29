import { ActivityLogSettings, EntraIdLogSettings } from '../../models/log-ingestion.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike 
   Log Ingestion module.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Tags to be applied to all deployed resources. Used for resource organization, governance, and cost tracking.')
param tags object

@description('Configuration settings for Azure Activity Log collection and monitoring.')
param activityLogSettings ActivityLogSettings

@description('Configuration settings for Microsoft Entra ID log collection and monitoring.')
param entraIdLogSettings EntraIdLogSettings

@description('List of IP addresses of CrowdStrike Falcon service. Please refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0 for the IP address list of your Falcon region.')
param falconIpAddresses array

@description('List of Azure subscription IDs to monitor. These subscriptions will be configured for CrowdStrike monitoring.')
param subscriptionIds array

/* Variables */
var environment = length(env) > 0 ? '-${env}' : env
var scope = az.resourceGroup(resourceGroupName)
var shouldDeployEventhubForActivityLog = activityLogSettings.enabled && !(activityLogSettings.?existingEventhub.use ?? false)
var shouldDeployEventhubForEntraIdLog = entraIdLogSettings.enabled && !(entraIdLogSettings.?existingEventhub.use ?? false)

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'eventHub.bicep' = {
  name: '${resourceNamePrefix}cs-log-eventhub${environment}-${location}${resourceNameSuffix}'
  scope: scope
  params: {
    activityLogSettings: activityLogSettings
    entraLogSettings: entraIdLogSettings
    falconIpAddresses: falconIpAddresses
    azurePrincipalId: azurePrincipalId
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    tags: tags
    location: location
    env: env
  }
}

/* Deploy Activity Log Diagnostic Settings for current Azure subscription */
var activityLogDiagnosticSettingsName = '${resourceNamePrefix}diag-cslogact${environment}${resourceNameSuffix}'
module activityDiagnosticSettings 'activityLog.bicep' = [
  for subId in subscriptionIds: if (shouldDeployEventhubForActivityLog) {
    name: '${resourceNamePrefix}cs-log-activity-diag${environment}${resourceNameSuffix}'
    scope: subscription(subId)
    params: {
      diagnosticSettingsName: activityLogDiagnosticSettingsName
      eventHubName: eventHub.outputs.eventhubs.activityLog.eventHubName
      eventHubAuthorizationRuleId: eventHub.outputs.eventhubs.activityLog.eventHubAuthorizationRuleId
    }
  }
]

module entraDiagnosticSettings 'entraLog.bicep' = if (shouldDeployEventhubForEntraIdLog) {
  name: '${resourceNamePrefix}cs-log-entid-diag${resourceNameSuffix}'
  params: {
    diagnosticSettingsName: '${resourceNamePrefix}diag-cslogentid${environment}${resourceNameSuffix}'
    eventHubName: eventHub.outputs.eventhubs.entraLog.eventHubName
    eventHubAuthorizationRuleId: eventHub.outputs.eventhubs.entraLog.eventHubAuthorizationRuleId
  }
}

/* Deployment outputs required for follow-up activities */
output eventHubAuthorizationRuleIdForActivityLog string = eventHub.outputs.eventhubs.activityLog.eventHubAuthorizationRuleId
output eventHubAuthorizationRuleIdForEntraLog string = eventHub.outputs.eventhubs.entraLog.eventHubAuthorizationRuleId
output activityLogEventHubName string = eventHub.outputs.eventhubs.activityLog.eventHubName
output activityLogEventHubId string = eventHub.outputs.eventhubs.activityLog.eventHubId
output activityLogDiagnosticSettingsName string = activityLogDiagnosticSettingsName
output activityLogEventHubConsumerGroupName string = eventHub.outputs.eventhubs.activityLog.eventHubConsumerGrouopName
output entraLogEventHubName string = eventHub.outputs.eventhubs.entraLog.eventHubName
output entraLogEventHubId string = eventHub.outputs.eventhubs.entraLog.eventHubId
output entraLogEventHubConsumerGroupName string = eventHub.outputs.eventhubs.entraLog.eventHubConsumerGrouopName
