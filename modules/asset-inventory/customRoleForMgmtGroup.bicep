targetScope = 'managementGroup'
/*
  This Bicep template defines the required permissions at Azure management group scope to enable CrowdStrike
  Asset Inventory
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@description('Optional prefix added to all resource names for organization and identification purposes.')
param resourceNamePrefix string

@description('Optional suffix added to all resource names for organization and identification purposes.')
param resourceNameSuffix string

@description('Environment label (e.g., prod, stag, dev) used for resource naming and tagging. Helps distinguish between different deployment environments.')
param env string

var customRole = {
  roleName: 'role-csreader'
  roleDescription: 'CrowdStrike custom role to allow read access to App Service and Function.'
  roleActions: [
    'Microsoft.Web/sites/Read'
    'Microsoft.Web/sites/config/Read'
    'Microsoft.Web/sites/config/list/Action'
    'Microsoft.Web/sites/publish/action'
  ]
}

var roleName = '${resourceNamePrefix}${customRole.roleName}-${managementGroup().name}${resourceNameSuffix}'
resource customRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(roleName, tenant().tenantId, managementGroup().id, env)
  properties: {
    assignableScopes: [managementGroup().id]
    description: customRole.roleDescription
    permissions: [
      {
        actions: customRole.roleActions
        notActions: []
      }
    ]
    roleName: roleName
    type: 'CustomRole'
  }
}

output id string = customRoleDefinition.id
output name string = customRoleDefinition.properties.roleName
