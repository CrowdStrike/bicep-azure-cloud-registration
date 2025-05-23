targetScope = 'managementGroup'

/*
  This Bicep template creates and assigns an Azure Policy used to ensure
  that Activity Log data is forwarded to CrowdStrike
  Copyright (c) 2025 CrowdStrike, Inc.
*/

/* Parameters */
@description('Azure region where the policy resources will be deployed. This should match the region of your monitored resources for optimal performance.')
param location string

@minLength(36)
@maxLength(36)
@description('Subscription ID where the Event Hub for Activity Logs is located. Used to target the correct Event Hub for diagnostic settings.')
param eventhubSubscriptionId string

@description('Resource group name where the Event Hub for Activity Logs is located. Used to target the correct Event Hub for diagnostic settings.')
param eventhubResourceGroupName string

@description('Resource ID of the Event Hub that will receive Activity Logs. Used for role assignments to grant access permissions.')
param eventhubId string

@description('Resource ID of the Event Hub Authorization Rule that grants "Send" permissions. Used to configure diagnostic settings to send logs to the Event Hub.')
param eventHubAuthorizationRuleId string

@description('Name for the diagnostic settings configuration that sends Activity Logs to the Event Hub. Used for identification in the Azure portal.')
param activityLogDiagnosticSettingsName string

@description('Name of the Event Hub instance where Activity Logs will be sent. This Event Hub must exist within the namespace referenced by the authorization rule.')
param eventHubName string

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

/* Variables */
var policyDefinition = json(loadTextContent('../../policies/log-ingestion/activity-log-policy.json'))

/* Resources */
resource activityLogPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: '${resourceNamePrefix}policy-cslogact${resourceNameSuffix}'
  properties: {
    displayName: policyDefinition.properties.displayName
    description: policyDefinition.properties.description
    policyType: policyDefinition.properties.policyType
    metadata: policyDefinition.properties.metadata
    mode: policyDefinition.properties.mode
    parameters: policyDefinition.properties.parameters
    policyRule: policyDefinition.properties.policyRule
  }
}

resource activityLogPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'pas-cslogact' // The maximum length is 24 characters
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    assignmentType: 'Custom'
    description: 'Ensures that Activity Log data is send to CrowdStrike for Real Time Visibility and Detection assessment.'
    displayName: 'CrowdStrike Activity Log Collection'
    enforcementMode: 'Default'
    policyDefinitionId: activityLogPolicyDefinition.id
    parameters: {
      eventHubAuthorizationRuleId: {
        value: eventHubAuthorizationRuleId
      }
      eventHubName: {
        value: eventHubName
      }
      eventHubSubscriptionId: {
        value: eventhubSubscriptionId
      }
      diagnosticSettingName: {
        value: activityLogDiagnosticSettingsName
      }
    }
  }
}

resource activityLogPolicyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in [
    '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
    '2a5c394f-5eb7-4d4f-9c8e-e8eae39faebc' // Lab Services Reader
    'f526a384-b230-433a-b45c-95f59c4a2dec' // Azure Event Hubs Data Owner
  ]: {
    name: guid(activityLogPolicyAssignment.id, roleDefinitionId)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
      principalId: activityLogPolicyAssignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

module eventHubRoleAssignment 'eventHubRoleAssignment.bicep' = {
  name: '${resourceNamePrefix}cs-log-pas-ra-${managementGroup().name}${resourceNameSuffix}'
  scope: az.resourceGroup(eventhubSubscriptionId, eventhubResourceGroupName)
  params: {
    eventHubId: eventhubId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec') // Azure Event Hubs Data Owner
    azurePrincipalId: activityLogPolicyAssignment.identity.principalId
  }
}
