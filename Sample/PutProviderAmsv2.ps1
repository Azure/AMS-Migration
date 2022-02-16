function Put-AmsV2Provider($subscriptionId, $resourceGroup, $monitorName, $request, $logger)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName Arm
    $armToken = $rawToken.Token
    $apiVersion = "2021-12-01-preview"

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    }

    $providerName = $request.name
    $bodyStr = ConvertTo-Json $request.body
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Workloads/monitors/$monitorName/providerInstances/" + $providerName + "?api-version=$apiVersion"
    $logger.LogInfo($url)

    $logger.LogTrace("$providerName Url: $url")
    $logger.LogTrace("$providerName Body: $bodyStr")

    $error = $null
    try
    {
        $response = Invoke-RestMethod -Method 'Put' -Uri $url -Headers $headers -Body $bodyStr
    }
    catch
    {
        $error = $_.ErrorDetails
    }

    $logger.LogInfo($response)
    return @{
      Response = $response
      Error = $error
    }
}