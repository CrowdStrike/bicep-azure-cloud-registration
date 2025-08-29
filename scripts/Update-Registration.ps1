## CrowdStrike API Client Scopes required:
## - Cloud security Azure registration (Write)
using namespace System.Runtime.Serialization

param (
    [Parameter(Mandatory = $true)]
    [string]$AzureTenantId,

    [Parameter(Mandatory = $true)]
    [System.Boolean]$IsInitialRegistration,

    [Parameter(Mandatory = $true)]
    [string]$EventHubsJson
)

# Get CrowdStrike API Access Token
function Get-FalconAPIAccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FalconAPIBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    try {
        $Params = @{
            Uri     = "https://${FalconAPIBaseUrl}/oauth2/token"
            Method  = "POST"
            Headers = @{
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            Body    = @{
                client_id     = $ClientId
                client_secret = $ClientSecret
            }
        }
        return ((Invoke-WebRequest @Params).Content | ConvertFrom-Json).access_token
    }
    catch [System.Exception] { 
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

function Set-AzureEventHubsInfo {
    param (
        [Parameter(Mandatory = $true)]
        [System.Boolean]$IsInitialRegistration,

        [Parameter(Mandatory = $true)]
        [string]$FalconAPIBaseUrl,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$AzureTenantId,

        [Parameter(Mandatory = $true)]
        [string]$EventHubsJson
    )
    try {
        $Params = @{
            Uri     = ($IsInitialRegistration) ? "https://${FalconAPIBaseUrl}/cloud-security-registration-azure/entities/registrations/partial/v1" : "https://${FalconAPIBaseUrl}/cloud-security-registration-azure/entities/registrations/v1"
            Method  = "PATCH"
            Headers = @{
                "Authorization" = "Bearer ${AccessToken}"
                "Content-Type" = "application/json"
            }
            Body = @{
                resource = @{
                    tenant_id = $AzureTenantId
                    event_hub_settings = @($EventHubsJson | ConvertFrom-Json)
                }
            } | ConvertTo-Json -Depth 4
        }
        Write-Output "Update registration. Url: $($Params.Uri)"
        Write-Output "Update registration. Request body: $($Params.Body)"
        $response = Invoke-WebRequest @Params
        Write-Output "Update registration success. Response: $($response.Content)`n"
    }
    catch [System.Exception] { 
        Write-Error "An exception was caught: $($_.Exception.Message), $($_.ErrorDetails.Message)"
        break
    }
}

$accessToken = $(Get-FalconAPIAccessToken -FalconAPIBaseUrl $Env:FALCON_API_BASE_URL -ClientId $Env:FALCON_CLIENT_ID -ClientSecret $Env:FALCON_CLIENT_SECRET)
Set-AzureEventHubsInfo -IsInitialRegistration $IsInitialRegistration -FalconAPIBaseUrl $Env:FALCON_API_BASE_URL -AccessToken $accessToken -AzureTenantId $AzureTenantId -EventHubsJson $EventHubsJson