<#
.SYNOPSIS
Function to set the Context using subscription id and Tenant Id.

.PARAMETER subscriptionId
Subscription Id for the AMS Monitor.

.PARAMETER tenantId
tenant Id for the AMS Monitor.

.PARAMETER logger
logger object.

.EXAMPLE
Set-CurrentContext -subscriptionId $subscriptionId -tenantId $tenantId -logger $logger
#>
function Set-CurrentContext($subscriptionId, $tenantId, $logger)
{
    Get-AzSubscription -SubscriptionId $subscriptionId -TenantId $tenantId | Set-AzContext
}

<#
.SYNOPSIS
Function that parses the ARM id and returns the Subscriptionid, ResourceGroupName, Monitor name.

.PARAMETER armId
ARM Id for the AMS v1 monitor.

.EXAMPLE
Get-ParsedArmId -armId $armId
#>
function Get-ParsedArmId($armId)
{
    $CharArray =$armId.Split("/")
    $i=2

    $parsedInput = @{
        subscriptionId = $CharArray[$i]
        amsResourceGroup = $CharArray[$i+2]
        amsResourceName = $CharArray[$CharArray.Length-1]
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