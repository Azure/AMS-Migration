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
function Set-CurrentContext($subscriptionId, $logger)
{
	$logger.LogInfo("Setting context for the current user with SubscriptionId $subscriptionId and tenant $tenantId");
    Get-AzSubscription -SubscriptionId $subscriptionId | Set-AzContext
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

<#
.SYNOPSIS
Function to get the SAP Netweaver Provider List.
Prints a summary of all the SAP Netweaver Providers in Azure AMS v2.

.PARAMETER sapNetWeaverTransformedList
List of SAP Netweaver Providers.

.EXAMPLE
Get-SapNetWeaverProvidersList $sapNetWeaverTransformedList
#>
function Get-SapNetWeaverProvidersList([System.Collections.ArrayList]$sapNetWeaverTransformedList)
{
	if($sapNetWeaverTransformedList.Count -eq 0) {
		return;
	}
    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing migrating SapNetWeaver provider(s)")
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE                        State"
    Write-Host "|--------------------------------------------------------------------------------------------|";
    foreach ($sapNetWeaverProvider in $sapNetWeaverTransformedList)
    {
        Write-Host "    " $sapNetWeaverProvider.name  -NoNewline
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
        Write-Host -NoNewline $sapNetWeaverProvider.type

		for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
		Write-Host -NoNewline      "|    "

        Write-Host $sapNetWeaverProvider.state;
    }
    Write-Host "|--------------------------------------------------------------------------------------------|";
	Write-Host "";
}

<#
.SYNOPSIS
Function to get the SAP Provider list which are not supported.
Prints a summary of all the unsupported SAP Providers in Azure AMS v2.

.PARAMETER unsupportedProviderList
List of SAP Providers which are not supported currently.

.EXAMPLE
Get-UnsupportedProvidersList $unsupportedProviderList
#>
function Get-UnsupportedProvidersList([System.Collections.ArrayList]$unsupportedProviderList)
{
	if($unsupportedProviderList.Count -eq 0) {
		return;
	}
    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing unsupported provider(s)");
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE                        State"
    Write-Host "|--------------------------------------------------------------------------------------------|";
    foreach ($unsupportedProvider in $unsupportedProviderList)
    {
        Write-Host "    " $unsupportedProvider.name  -NoNewline
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
        Write-Host -NoNewline $unsupportedProvider.type

		for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
		Write-Host -NoNewline      "|    "

        Write-Host $unsupportedProvider.state;
    }
	Write-Host  "|--------------------------------------------------------------------------------------------|";
	Write-Host "";
}

<#
.SYNOPSIS
Function to get the SAP Hana Provider List.
Prints a summary of all the SAP Hana Providers in Azure AMS v2.

.PARAMETER saphanaTransformedList
List of SAP HANA Providers.

.EXAMPLE
 Get-SapHanaProvidersList $saphanaTransformedList
#>
function Get-SapHanaProvidersList([System.Collections.ArrayList]$saphanaTransformedList)
{
	if($saphanaTransformedList.Count -eq 0) {
		return;
	}

    $width = 25
    Write-Host
    Write-Host
    $logger.LogInfo("Listing migrating SapHana provider(s)")
    Write-Host
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE                        State"
    Write-Host "|--------------------------------------------------------------------------------------------|";
    foreach ($saphanaProvider in $saphanaTransformedList)
    {
        Write-Host "    " $saphanaProvider.name  -NoNewline
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
        Write-Host -NoNewline $saphanaProvider.type

		for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
		Write-Host -NoNewline      "|    "

        Write-Host $saphanaProvider.state;
    }
    Write-Host  "|--------------------------------------------------------------------------------------------|";
	Write-Host "";
}

# Install module pre-requisites
<#
.SYNOPSIS
Function to Install azure module pre-requisites

.EXAMPLE
InstallModules
#>
function InstallModules()
{
    try {
        $m = Get-InstalledModule Az -MinimumVersion 5.1.0 -ErrorAction "Stop"
    }
    catch {
    }
    if ($null -eq $m)
    {
        Write-Host -ForegroundColor Green "Installing Az Module."
        Install-Module Az -AllowClobber
        Write-Host -ForegroundColor Green "Installed Az Module."
    }
    else {
        Import-Module Az
        Write-Host -ForegroundColor Green "Importing installed Az Module."
    }

    $m = $null
    try {
        $m = Get-InstalledModule AzureAD -MinimumVersion 2.0.2.61 -ErrorAction "Stop"
    }
    catch {
    }
    if ($null -eq $m)
    {
        Write-Host -ForegroundColor Green "Installing AzureAD Module."
        Install-Module AzureAD
        Write-Host -ForegroundColor Green "Installed AzureAD Module."
    }
    else {
        Import-Module AzureAD
    }
}

<#
.SYNOPSIS
Function to Parse all the SAP Netweaver host file entries.

.PARAMETER fileName
Path of the 
.PARAMETER logger
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function ParseSapNetWeaverHostfile($fileName, $logger)
{
	$logger.LogInfo("Parsing host.json file.");
    $fileName = "hosts.json"

    $logFilePath = Join-Path $PSScriptRoot "\$fileName"

    $content = (Get-Content "$logFilePath" | Out-String)
    $content = ConvertFrom-Json $content

    $hashTable = @{}

    foreach($i in $content)
    {
        $logger.LogInfo("Found Provider $($i.providerName)");
        $logger.LogInfo("with host file entries : $($i.sapHostFileEntries)");
        $hashTable.add($i.providerName,$i.sapHostFileEntries)
    }
    return $hashTable
}