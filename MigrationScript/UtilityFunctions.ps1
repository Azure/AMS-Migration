function Set-CurrentContext($subscriptionId, $tenantId, $logger)
{
    Get-AzSubscription -SubscriptionId $subscriptionId -TenantId $tenantId | Set-AzContext
}

function Get-ParsedArmId($armId)
{
    $CharArray =$armId.Split("/")
    $i=2

    $parsedInput = @{
        subscriptionId = $CharArray[$i]
        amsV1ResourceGroup = $CharArray[$i+2]
        amsv1ResourceName = $CharArray[$CharArray.Length-1]
    }

    return $parsedInput
}

function Get-SapNetWeaverProvidersList($sapNetWeaverTransformedList)
{
    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing migrating SapNetWeaver provider(s)")
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($sapNetWeaverProvider in $sapNetWeaverTransformedList)
    {
        Write-Host -NoNewline "    " $sapNetWeaverProvider.name
        $spaces = $width - $sapNetWeaverProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $sapNetWeaverProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}

function Get-UnsupportedProvidersList($unsupportedProviderList)
{
    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing unsupported provider(s)")
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($unsupportedProvider in $unsupportedProviderList)
    {
        Write-Host -NoNewline "    " $unsupportedProvider.name
        $spaces = $width - $unsupportedProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $unsupportedProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}

function Get-SapHanaProvidersList($saphanaTransformedList)
{
    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing migrating SapHana provider(s)")
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($saphanaProvider in $saphanaTransformedList)
    {
        Write-Host -NoNewline "    " $saphanaProvider.name
        $spaces = $width - $saphanaProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $saphanaProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}