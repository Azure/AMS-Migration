function Get-AmsV2ProviderStatus([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, [string]$providerName, $logger)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName Arm
    $armToken = $rawToken.Token

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    }

    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Workloads/monitors/$monitorName/providerInstances/" + $providerName + "?api-version=2021-12-01-preview"

    $response = Invoke-RestMethod -Method 'get' -Uri $url -Headers $headers
    $provisiongState = $response.properties.provisioningState

    return $provisiongState
}
