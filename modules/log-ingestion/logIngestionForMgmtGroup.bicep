import { ActivityLogSettings } from '../../models/log-ingestion.bicep'

targetScope = 'managementGroup'

/*
  This Bicep template creates and assigns an Azure Policy used to ensure
  that Activity Log data is forwarded to CrowdStrike
  assessment.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@minLength(36)
@maxLength(36)
@description('Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs.')
param csInfraSubscriptionId string

@description('Resource ID of the Event Hub Authorization Rule that grants "Send" permissions. Used to configure diagnostic settings to send logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Name of the resource group where CrowdStrike infrastructure resources will be deployed.')
param resourceGroupName string

@description('Name for the diagnostic settings configuration that sends Activity Logs to the Event Hub. Used for identification in the Azure portal.')
param activityLogDiagnosticSettingsName string

@description('Name of the Event Hub instance where Activity Logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param activityLogEventHubName string

@description('Resource ID of the Event Hub that will receive Activity Logs. Used for role assignments to grant access permissions.')
param activityLogEventHubId string

@description('Configuration settings for Azure Activity Log collection and monitoring.')
param activityLogSettings ActivityLogSettings

@description('Azure location (aka region) where global resources (Role definitions, Event Hub, etc.) will be deployed. These tenant-wide resources only need to be created once regardless of how many subscriptions are monitored.')
param location string

module activityLogDiagnosticSettingsPolicyAssignment 'activityLogPolicy.bicep' = if (activityLogSettings.enabled && !(activityLogSettings.?existingEventhub.use ?? false) && (activityLogSettings.?deployRemediationPolicy ?? true)) {
  name: '${resourceNamePrefix}cs-log-policy-${location}${resourceNameSuffix}'
  params: {
    eventHubName: activityLogEventHubName
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventhubSubscriptionId: csInfraSubscriptionId
    eventhubResourceGroupName: resourceGroupName
    eventhubId: activityLogEventHubId
    activityLogDiagnosticSettingsName: activityLogDiagnosticSettingsName
    resourceNamePrefix: resourceNamePrefix
    resourceNameSuffix: resourceNameSuffix
    location: location
  }
}
