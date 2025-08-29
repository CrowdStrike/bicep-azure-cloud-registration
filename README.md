![CrowdStrike Falcon](https://raw.githubusercontent.com/CrowdStrike/falconpy/main/docs/asset/cs-logo.png)

# Falcon Cloud Security Registration with Azure Bicep

The Azure Bicep templates in this repository allow for an easy and seamless registration of Azure environments into CrowdStrike Falcon Cloud Security for asset inventory and real-time visibility and detection.

## Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Required permissions](#required-permissions)
4. [Template Parameters](#template-parameters)
5. [Resource Names](#resource-names)
6. [Deployment](#deployment)
7. [Troubleshooting](#troubleshooting)
8. [Contributing](#contributing)
9. [Support](#support)
10. [License Information](#license-information)

## Overview

You can use the Bicep files in this repo to register either or both of these types of Azure entities to Falcon Cloud Security:
- Azure management groups and all subscriptions in those management groups 
- Individual Azure subscriptions 

The Bicep templates perform the following actions:

- Create a resource group named `rg-cs-prod` (with a custom prefix or suffix, if specified) in the specified subscription `csInfraSubscriptionId`. 
- Assign the `Reader` Azure RBAC permission to the created app registration with a scope of either the management groups or individual subscriptions, depending on which Bicep file is being used.
- If registering a management group, a user-assigned managed identity with `Reader` permissions on the specified management groups is created to list enabled subscriptions.
- Assign the **role-csreader-\<subscription ID\>/\<management group ID\>** custom role on the management group or subscription with the following actions:
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
  - Microsoft.Web/sites/publish/action
- If the `enableRealTimeVisibility` parameter is set to true, the templates also:
   - Deploy an Azure Event Hubs namespace, two event hubs, and additional infrastructure to the subscription that has been designated as the default subscription, which is done via the `csInfraSubscriptionId` parameter. CrowdStrike uses this infrastructure to stream Entra ID sign-in and audit logs, as well as Azure activity logs, to Falcon Cloud Security.
   - Create a Microsoft Entra ID diagnostic setting that forwards sign-in and audit logs to the newly-created event hub.
   - Individual subscription deployments only:
      - Create an Azure activity log diagnostic setting in the subscription being registered with Falcon Cloud Security that forwards activity logs to the newly-created event hub.
   - If registering a management group:
      - Create an Azure activity log diagnostic setting in all active subscriptions that forwards activity logs to the newly-created event hub.
      - When `logIngestionSettings.activityLogSettings.deployRemediationPolicy` is set to `true`, create an Azure policy definition and management group assignment that will create Azure activity log diagnostic settings for new subscriptions to forward activity logs to the newly-created event hub.

> [!NOTE]
> The user-assigned managed identity created during management group deployment is only used to get a list of all active subscriptions in the specified management groups and can be safely removed after a successful registration. The underlying resources using the user-assigned managed identity are removed automatically.

## Prerequisites

1. Create a registration for your Azure tenant on Falcon Cloud Security and grant admin consent to Falcon Cloud Security App
   - [US-1](https://falcon.crowdstrike.com/cloud-security/registration-v2/azure)
   - [US-2](https://falcon.us-2.crowdstrike.com/cloud-security/registration-v2/azure)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/cloud-security/registration-v2/azure)
2. Ensure you have a CrowdStrike API URL, client ID, and client secret for Falcon Cloud Security with `Cloud security Azure registration (Write)` scope. If you don't already have API credentials, you can set them up in the Falcon console. You must be a Falcon Administrator to access the API clients page:
   - [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
   - [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
   - [EU-1](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

3. Install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) on your local computer or use `Azure Cloud Shell` in the Azure portal.

4. If you're registering a management group and `enableRealTimeVisibility` is set to `true`, ensure the `Microsoft.Management` resource provider is registered in the `csInfraSubscriptionId` subscription. This allows the template to discover active subscriptions under the specified management groups. You can register it using either of these methods:

   **Using Azure CLI:**
   ```
   az provider register --namespace Microsoft.Management --subscription <csInfraSubscriptionId>
   ```

   **Using Azure Portal:**
   1. Sign in to the Azure Portal.
   2. Navigate to the subscription specified in `csInfraSubscriptionId`.
   3. In the left menu, select **Settings** > **Resource providers**.
   4. Search for `Microsoft.Management` in the filter box.
   5. Select `Microsoft.Management` and click **Register** at the top of the page.
   6. Wait for the status to change from "Registering" to "Registered".


## Required permissions

- **Owner** role for the Azure management groups and subscriptions to be integrated into Falcon Cloud Security

## Template parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [Deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [Inline parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                                                                | Required | Description                                                                                                                                                                                               |
|-------------------------------------------------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `csInfraSubscriptionId`                                                       | no       | Subscription ID where CrowdStrike infrastructure resources will be deployed. This subscription hosts shared resources like Event Hubs. Required when `enableRealTimeVisibility` is set to `true`.         |
| `managementGroupIds`                                                          | no       | List of management groups to be integrated into Falcon Cloud Security. Only used to register management groups.                                                                                           |
| `subscriptionIds`                                                             | no       | List of individual subscriptions to be integrated into Falcon Cloud Security.                                                                                                                             |
| `location`                                                                    | no       | Azure location (region) where global resources will be deployed. Default is the deployment location.                                                                                                  |
| `resourceNamePrefix`                                                          | no       | Optional prefix added to all resource names for organization and identification purposes.                                                                                                                 |
| `resourceNameSuffix`                                                          | no       | Optional suffix added to all resource names for organization and identification purposes.                                                                                                                 |
| `falconIpAddresses`                                                           | no       | Falcon public IP addresses. Only used when `logIngestionSettings.enabled` is set to `true`. These will be configured to public network access list of EventHubs. For the list of IP addresses for your Falcon region, refer to https://falcon.crowdstrike.com/documentation/page/re07d589/add-crowdstrike-ip-addresses-to-cloud-provider-allowlists-0. |
| `falconApiFqdn`                                                               | no       | Falcon API FQDN for your CrowdStrike environment (`api.crowdstrike.com`, `api.us-2.crowdstrike.com`, or `api.eu-1.crowdstrike.com`). Required when `enableRealTimeVisibility` is set to `true`. |
| `falconClientId`                                                              | no       | Falcon API Client ID with CSPM Registration Read and Write scopes. Required when `enableRealTimeVisibility` is set to `true`.                                                                         |
| `falconClientSecret`                                                          | no       | Falcon API Client Secret for the provided Client ID. Required when `enableRealTimeVisibility` is set to `true`.                                                                                       |
| `azurePrincipalId`                                                            | yes      | Principal ID of Falcon Cloud Security App in Entra ID.                                                                                                                                                    |
| `env`                                                                         | no       | Environment label (For example, prod, stag, or dev) used for resource naming and tagging. Default is `prod`.                                                                                                   |
| `tags`                                                                        | no       | Tags to be applied to all deployed resources. Used for resource organization and governance.                                                                                                              |
| `isInitialRegistration`                                                       | no       | Indicates whether this is the initial registration. Default is `true`.           |
| `enableRealTimeVisibility`                                                    | no       | Main toggle for the log ingestion module. When set to true, all related resources will be deployed. Default is `false`.                                                                                |
| `logIngestionSettings.activityLogSettings.enabled`                            | no       | Controls whether activity log diagnostic settings are deployed to monitored Azure subscriptions. Default is `true`.                                                                                      |
| `logIngestionSettings.activityLogSettings.deployRemediationPolicy`            | no       | Controls whether to deploy a policy that automatically configures activity log diagnostic settings on new subscriptions. Default is `true`.                                                              |
| `logIngestionSettings.entraIdLogSettings.enabled`                             | no       | Controls whether Entra ID log diagnostic settings are deployed. When false, Entra ID logs are not collected. Default is `true`.                                                                      |
| `logIngestionSettings.activityLogSettings.existingEventhub`                   | no       | Collection of settings used to configure an existing event hub instead of creating a new one for activity logs.                                                                                                           |
| `logIngestionSettings.activityLogSettings.existingEventhub.use`               | no       | When set to true, an existing event hub will be used instead of creating a new one. Default is `false`.                                                                                                  |
| `logIngestionSettings.activityLogSettings.existingEventhub.subscriptionId`    | no       | Subscription ID where the existing event hub is located.                                                                                                                                                  |
| `logIngestionSettings.activityLogSettings.existingEventhub.resourceGroupName` | no       | Resource group name where the existing event hub is located.                                                                                                                                              |
| `logIngestionSettings.activityLogSettings.existingEventhub.namespaceName`     | no       | Name of the existing event hub namespace.                                                                                                                                                                 |
| `logIngestionSettings.activityLogSettings.existingEventhub.name`              | no       | Name of the existing event hub instance to use.                                                                                                                                                           |
| `logIngestionSettings.activityLogSettings.existingEventhub.consumerGroupName` | no       | Consumer group name in the existing event hub instance to use.                                                                                                                                            |
| `logIngestionSettings.entraIdLogSettings.existingEventhub`                    | no       | Configuration for using an existing event hub instead of creating a new one for Entra ID Logs.                                                                                                            |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.use`                | no       | When set to true, an existing event hub will be used instead of creating a new one. Default is `false`.                                                                                                  |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.subscriptionId`     | no       | Subscription ID where the existing event hub is located.                                                                                                                                                  |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.resourceGroupName`  | no       | Resource group name where the existing event hub is located.                                                                                                                                              |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.namespaceName`      | no       | Name of the existing Azure Event Hubs namespace.                                                                                                                                                                 |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.name`               | no       | Name of the existing event hub instance to use.                                                                                                                                                           |
| `logIngestionSettings.entraIdLogSettings.existingEventhub.consumerGroupName`  | no       | Consumer group name in the existing event hub instance to use.                                                                                                                                            |

## Deployment

### Preparation

1. Download this repo to your local computer.
2. Open a new Terminal window and change directory to point at the downloaded repo.
3. Run `az login` to log into Azure via the Azure CLI. Be sure to log into a subscription that is in the tenant you want to register with Falcon Cloud Security.
4. Run the appropriate deployment command provided below.

### Deployment command for registering management groups and/or individual subscriptions

```sh
az stack mg create --name '<deployment stack name you want to use>' --location westus \
  --management-group-id '<management group id that the deployment stack to be created at>' \
  --template-file cs-deployment-management-group.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

> [!NOTE]
> The `cs-deployment-management-group.bicep` template can be used to register a list of management groups (and all subscriptions in those management groups) and/or a list of individual subscriptions to CrowdStrike Falcon Cloud Security.

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal.
   - Go to **Management Groups** > **[management group of the deployment stack]**.
   - In the left menu, select **Governance** > **Deployment stacks**.
   - You will find the name you specified in the above command.


#### Remediate existing subscriptions using Azure Policy

> [!NOTE]
> This section is only applicable when `logIngestionSettings.activityLogSettings.deployRemediationPolicy` is set to `true`.

If the default deployment of Azure activity log diagnostic settings to all active subscriptions has been disabled, you can use a remediation task as part of Azure Policy to deploy Azure activity log diagnostic settings to existing subscriptions in a tenant to enable `Real Time Visibility and Detection (RTV&D)`.

> [!NOTE]
> After an Azure Policy assignment has been created, it takes time for Azure Policy to evaluate the compliance state of existing subscriptions. There is no predefined expectation of when the evaluation cycle completes. For more information, see [Azure Policy Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers).

To start a manual remediation task:

1. In the Azure portal, navigate to **Management Groups** and select the tenant root group.
2. Go to **Governance** > **Policy** and select **Authoring** > **Assignments**.
3. Click the **CrowdStrike Activity Log Collection** assignment and then remediate the assignment by [creating a remediation task from a non-compliant policy assignment](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#option-2-create-a-remediation-task-from-a-non-compliant-policy-assignment).


### Deployment command for registering individual subscriptions

```sh
az stack sk create --name '<deployment stack name you want to use>' --location westus \
  --template-file cs-deployment-subscription.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

To track progress of the deployment or if you encounter issues and want to see detailed error messages:
   - Open the Azure Portal.
   - Go to **Subscriptions** and select the Subscription where you ran the deployment command.
   - In the left menu, select **Settings** > **Deployment stacks**.
   - You will find the name you specified in the above command.

### Deployment command for registering the whole tenant

To deploy Falcon Cloud Security integration for the entire tenant, you can use the management group deployment template with empty lists for both `managementGroupIds` and `subscriptionIds` parameters:

```sh
az stack mg create --name '<deployment stack name you want to use>' --location westus \
  --management-group-id '<tenant root management group id>' \
  --template-file cs-deployment-management-group.bicep \
  --parameters '<file path of the Bicep parameter file storing all the input parameters>' \
  --action-on-unmanage deleteAll \
  --deny-settings-mode None \
  --only-show-errors
```

In your parameters file, ensure both `managementGroupIds` and `subscriptionIds` are set to empty arrays:

```bicep
param managementGroupIds = []
param subscriptionIds = []
```

This configuration deploys the Falcon Cloud Security integration at the tenant root level, effectively covering all management groups and subscriptions in your Azure tenant.

To track progress of the deployment:
   - Open the Azure Portal.
   - Go to **Management Groups** > **[tenant root management group]**.
   - In the left menu, select **Governance** > **Deployment stacks**.
   - You will find the name you specified in the above command.

## Troubleshooting

### SSL certificate verification failure
Some customers may encounter an error message when trying to run the deployment command, similar to: `Error while attempting to retrieve the latest Bicep version: HTTPSConnectionPool(host='aka.ms', port=443): Max retries exceeded with url: /BicepLatestRelease (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1000)')))`

This is usually caused by the presence of a web proxy on your network using self-signed certificates. The Azure CLI has a dependency on Python and Python is not using the correct certificates to make requests. The easiest solution is to download the Bicep tools independently of the Azure CLI and then tell the Azure CLI to use that version of Bicep tools when needed. Here's how:
1. Follow [Microsoft's instructions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#install-manually) on how to manually install the Bicep tools on your local computer.
2. Open a new terminal window on your computer and run the following command, which tells Azure CLI to use the manually downloaded version of Bicep tools instead of trying to install the tools as part of Azure CLI: `az config set bicep.use_binary_from_path=True`
3. Follow the deployment instructions again. This time, it should work without issue.

### Real-time visibility and detection appears inactive for discovered subscriptions after registering an Azure management group

After registering a management group and manually remediating the `CrowdStrike Activity Log Collection` policy assignment, real-time visibility and detection can remain inactive for some discovered subscriptions. This can happen when the diagnostic settings are not configured in the registered subscriptions.

The evaluation of the assigned Azure policy responsible for the diagnostic settings creation can take some time to properly evaluate which resources need to be remediated. For details, see [Evaluation Triggers](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/get-compliance-data#evaluation-triggers).

Make sure that all the existing subscriptions are properly listed under [resources to remediate](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#step-2-specify-remediation-task-details) when creating the remediation tasks.

### Deleting the deployment stack fails if Microsoft Entra ID Log is enabled in log ingestion module

When Microsoft Entra ID Log is enabled and not using an existing Event Hubs instance in the Log Ingestion module, the deletion of the deployment stack may fail with the following error:

```
(DeploymentStackDeleteResourcesFailed) One or more resources could not be deleted. Correlation id: '...'.
Code: DeploymentStackDeleteResourcesFailed
Message: One or more resources could not be deleted. Correlation id: '...'.
Exception Details: (DeploymentStackDeleteResourcesFailed) An error occurred while deleting resources. 
These resources are still present in the stack but can be deleted manually. 
Please see the FailedResources property for specific error information. 
Deletion failures that are known limitations are documented here: https://aka.ms/DeploymentStacksKnownLimitations
```

This occurs because the Entra ID diagnostic settings resource has dependencies that prevent automatic deletion through the deployment stack.

To delete the deployment stack successfully, follow these steps:

1. Attempt to delete the deployment stack with the following command. The deletion will fail with the above error:
   ```
   az stack sub delete --name <deployment-stack-name> --action-on-unmanage deleteAll
   ```
   or for management group deployments:
   ```
   az stack mg delete --name <deployment-stack-name> --management-group-id <management-group-id> --action-on-unmanage deleteAll
   ```

2. In the Azure portal, navigate to the deployment stack:
   - For subscription deployments: Go to **Subscriptions** > **[your subscription]** > **Settings** > **Deployment stacks**
   - For management group deployments: Go to **Management Groups** > **[your management group]** > **Governance** > **Deployment stacks**

3. Select the deployment stack that failed to delete.

4. In the deployment stack details, find the list of failed resources and click the name of the Entra ID log diagnostic settings resource.

5. Click **Delete** to manually delete this resource.

6. After the diagnostic settings resource is successfully deleted, detach the deployment stack:
   ```
   az stack sub delete --name <deployment-stack-name> --action-on-unmanage detachAll
   ```
   or for management group deployments:
   ```
   az stack mg delete --name <deployment-stack-name> --management-group-id <management-group-id> --action-on-unmanage detachAll
   ```

## Contributing

If you want to develop new content or improve on this collection, please open an issue or create a pull request. All contributions are welcome!

## Support

This is a community-driven, open source project aimed to register Falcon Cloud Security with Azure using Bicep. While not an official CrowdStrike product, this repository is maintained by CrowdStrike and supported in collaboration with the open source developer community.

For additional information, please refer to the [SUPPORT.md](SUPPORT.md) file.

## License Information

See the [LICENSE](LICENSE) for more information.
