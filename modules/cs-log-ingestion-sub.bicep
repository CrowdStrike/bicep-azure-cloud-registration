import { ActivityLogSettings, EntraIdLogSettings } from '../models/log-ingestion.bicep'

targetScope = 'subscription'

/*
  This Bicep template deploys Azure Activity Log and Microsoft Entra ID Diagnostic Settings
  to the target Azure subscriptions in the current Entra ID tenant.
  It configures Event Hubs and necessary permissions for CrowdStrike log ingestion.
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

@description('Principal ID of the CrowdStrike application registered in Entra ID. This service principal will be granted necessary permissions.')
param azurePrincipalId string

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

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

var environment = length(env) > 0 ? '-${env}' : env

module deploymentForSubs 'log-ingestion/logIngestionForSub.bicep' = {
  name: '${resourceNamePrefix}cs-log-sub${environment}${resourceNameSuffix}'
  params: {
    subscriptionIds: subscriptionIds
    resourceGroupName: resourceGroupName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    azurePrincipalId: azurePrincipalId
    activityLogSettings: activityLogSettings
    entraIdLogSettings: entraIdLogSettings
    falconIpAddresses: falconIpAddresses
    location: location
    env: env
    tags: tags
  }
}

output activityLogEventHubId string = deploymentForSubs.outputs.activityLogEventHubId
output activityLogEventHubConsumerGroupName string = deploymentForSubs.outputs.activityLogEventHubConsumerGroupName
output entraLogEventHubId string = deploymentForSubs.outputs.entraLogEventHubId
output entraLogEventHubConsumerGroupName string = deploymentForSubs.outputs.entraLogEventHubConsumerGroupName
