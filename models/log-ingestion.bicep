/*
  This Bicep template defines types and models for the CrowdStrike Log Ingestion module.
  Copyright (c) 2025 CrowdStrike, Inc.
*/

@export()
@description('Configuration settings for the log ingestion module that enables CrowdStrike to collect and analyze Azure Activity Logs and Entra ID audit logs for security monitoring and threat detection')
type LogIngestionSettings = {
  @description('Configuration for collecting Azure Activity Logs from subscriptions to monitor resource management activities, administrative actions, and service health events')
  activityLogSettings: ActivityLogSettings?

  @description('Configuration for collecting Entra ID audit and sign-in logs to monitor authentication events, directory changes, and identity-related security activities')
  entraIdLogSettings: EntraIdLogSettings?
}

@export()
type ActivityLogSettings = {
  @description('Controls whether Activity Log Diagnostic Settings are deployed to monitored Azure subscriptions. When false, activity logs will not be collected.')
  enabled: bool

  @description('Controls whether to deploy a policy that automatically configures Activity Log Diagnostic Settings on new subscriptions')
  deployRemediationPolicy: bool?

  @description('Configuration for using an existing Event Hub instead of creating a new one for Activity Logs')
  existingEventhub: ExistingEventHub?
}

@export()
type EntraIdLogSettings = {
  @description('Controls whether Entra ID Log Diagnostic Settings are deployed. When false, Entra ID logs will not be collected.')
  enabled: bool

  @description('Configuration for using an existing Event Hub instead of creating a new one for Entra ID Logs')
  existingEventhub: ExistingEventHub?
}

type ExistingEventHub = {
  @description('When set to true, an existing Event Hub will be used instead of creating a new one')
  use: bool

  @description('Subscription ID where the existing Event Hub is located')
  subscriptionId: string?

  @description('Resource group name where the existing Event Hub is located')
  resourceGroupName: string?

  @description('Name of the existing Event Hub Namespace')
  namespaceName: string?

  @description('Name of the existing Event Hub instance to use')
  name: string?

  @description('Consumer group name in the existing Event Hub instance to use')
  consumerGroupName: string?
}
