# ########### Header ###########
# Refer common library file
. $PSScriptRoot\ConsoleLogger.ps1
. $PSScriptRoot\UtilityFunctions.ps1
. $PSScriptRoot\KeyvaultHelperFunctions.ps1
# #############################

<#
.SYNOPSIS
Function to create a new Provider in AMS v2 Monitor.

.PARAMETER subscriptionId
SubscriptionId of the AMS v2 Monitor.

.PARAMETER resourceGroup
Resource Group Name of the AMS v2 Monitor.

.PARAMETER monitorName
AMS v2 Monitor Name.

.PARAMETER request
request object, it should have Name Property that has provider name and body property which has provider properties. 

.PARAMETER logger
logger object. 

.EXAMPLE
$requestObj = @{
				Name = $providerName
				body = @{
					properties = @{
						providerSettings = @{
							providerType = $providerType
							hostname = $Hostname
							dbName = $DbName
							sqlPort = $SqlPort
							dbUsername = $DbUsername
							dbPassword = $DbPassword
						}
					}
				}
			}
$logger = New-Object ConsoleLogger
PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
#>
function PutAmsV2HanaProvider([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, $request, $logger) {
	$rawToken = Get-AzAccessToken -ResourceTypeName Arm;
    $armToken = $rawToken.Token;
    $apiVersion = "2021-12-01-preview";

	$headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    };

	$providerName = $request.name;
    $bodyStr = $request.body | ConvertTo-Json ;
	[string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $subscriptionId;
	[string]$rgParams = "/resourceGroups/" + $resourceGroup;
	[string]$providerParams = "/providers/Microsoft.Workloads/monitors/" + $monitorName + "/providerInstances/" + $providerName + "?api-version=" + $apiVersion;

	$url = $url + $subscriptionParams + $rgParams + $providerParams;

	Write-Host "Making Put Provider call with $url";
	# Write-Host "body $bodyStr";
	try
    {
        $response = Invoke-RestMethod -Method 'Put' -Uri $url -Headers $headers -Body $bodyStr
    }
    catch
    {
        $putErrorMsg = $_.ErrorDetails | ConvertTo-Json -Depth 10;
		Write-Host ($($putErrorMsg.error.code));
		$logger.LogError("Put-AmsV2Provider : Failed with error: ($($putErrorMsg.error.code))", "", "");
    }

	return @{
		Response = $response
		Error = $putErrorMsg
	}
}

<#
.SYNOPSIS
Function to get the deployment status for Provider.

.PARAMETER subscriptionId
SubscriptionId of the AMS v2 Monitor.

.PARAMETER resourceGroup
Resource Group Name of the AMS v2 Monitor.

.PARAMETER monitorName
AMS v2 Monitor Name.

.PARAMETER providerName
Provider name.

.PARAMETER logger
logger object. 

.EXAMPLE
$logger = New-Object ConsoleLogger
GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
#>
function GetAmsV2ProviderStatus([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, [string]$providerName, $logger)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName Arm
    $armToken = $rawToken.Token
	$apiVersion = "2021-12-01-preview";

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    }

    [string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $subscriptionId;
	[string]$rgParams = "/resourceGroups/" + $resourceGroup;
	[string]$providerParams = "/providers/Microsoft.Workloads/monitors/" + $monitorName + "/providerInstances/" + $providerName + "?api-version=" + $apiVersion;
	$url = $url + $subscriptionParams + $rgParams + $providerParams;
	[string]$provisiongState = "";
	Write-Host "Making Get Provider call with $url";
    
	try
    {
        $response = Invoke-RestMethod -Method 'get' -Uri $url -Headers $headers;
		$provisiongState = $response.properties.provisioningState
    }
    catch
    {
        $GetProviderErrorMsg = $_.ErrorDetails.ToString();
		$logger.LogError("GetAmsV2ProviderStatus : Failed with error: ($($GetProviderErrorMsg.error.code)))", "500", "");
		$provisiongState = "Not Created"
    }

	return @{
		Response = $response
		provisiongState = $provisiongState
		Error = $GetProviderErrorMsg
	}
}

<#
.SYNOPSIS
Function to get the AMS v2 Monitor Properties.

.PARAMETER subscriptionId
SubscriptionId of the AMS v2 Monitor.

.PARAMETER resourceGroup
Resource Group Name of the AMS v2 Monitor.

.PARAMETER monitorName
AMS v2 Monitor Name.

.PARAMETER logger
logger object. 

.EXAMPLE
$logger = New-Object ConsoleLogger
GetAmsV2MonitorProperties -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger
#>
function GetAmsV2MonitorProperties([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, $logger)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName Arm
    $armToken = $rawToken.Token
	$apiVersion = "2021-12-01-preview";

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    }

    [string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $subscriptionId;
	[string]$rgParams = "/resourceGroups/" + $resourceGroup;
	[string]$providerParams = "/providers/Microsoft.Workloads/monitors/" + $monitorName + "?api-version=" + $apiVersion;
	$url = $url + $subscriptionParams + $rgParams + $providerParams;
	[string]$provisiongState = "";
	Write-Host "Making Get Monitor call with $url";
    
	try
    {
        $response = Invoke-RestMethod -Method 'get' -Uri $url -Headers $headers;
		$provisiongState = $response.properties.provisioningState
    }
    catch
    {
        $GetProviderErrorMsg = $_.ErrorDetails.ToString();
		$logger.LogError("GetAmsV2MonitorProperties : Failed with error: ($($GetProviderErrorMsg.error.code)))", "500", "");
		$provisiongState = "Not Created"
    }

	return @{
		Response = $response
		provisiongState = $provisiongState
		Error = $GetProviderErrorMsg
	}
}

<#
.SYNOPSIS
Function to get the managed keyvault for ams v2 monitor.

.PARAMETER subscriptionId
SubscriptionId of the AMS v2 Monitor.

.PARAMETER resourceGroup
Resource Group Name of the AMS v2 Monitor.

.PARAMETER monitorName
AMS v2 Monitor Name.

.PARAMETER logger
logger object. 

.EXAMPLE
$logger = New-Object ConsoleLogger
GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
#>
function GetAmsV2ManagedKv([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, $logger)
{    
	[string]$managedKvName = "";
	try
    {
        $response = GetAmsV2MonitorProperties -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger
		$managedRgName = $response.Response.properties.managedResourceGroupConfiguration.name;
		$logger.LogInfo("Managed RG Name associated with Monitor : $monitorName is $managedRgName");

		$kvDetails = Get-AzResource -ResourceGroupName $managedRgName -ResourceType Microsoft.KeyVault/vaults
		$logger.LogInfo("Managed KV Name associated with Monitor : $monitorName is $($kvDetails.Name)");
		$managedKvName = $kvDetails.Name;
    }
    catch
    {
        $GetProviderErrorMsg = $_.ErrorDetails.ToString();
		$logger.LogError("GetAmsV2ManagedKv : Failed with error: ($($GetProviderErrorMsg.error.code)))", "500", "");
    }

	return @{
		Response = $managedKvName
		Error = $GetProviderErrorMsg
	}
}

<#
.SYNOPSIS
Function to get the managed Function app name for ams v2 monitor.

.PARAMETER subscriptionId
SubscriptionId of the AMS v2 Monitor.

.PARAMETER resourceGroup
Resource Group Name of the AMS v2 Monitor.

.PARAMETER monitorName
AMS v2 Monitor Name.

.PARAMETER providerType
Provider Type.

.PARAMETER logger
logger object. 

.EXAMPLE
$logger = New-Object ConsoleLogger
GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
#>
function GetAmsV2ManagedFunc([string]$subscriptionId, [string]$resourceGroup, [string]$monitorName, [string]$providerType, $logger)
{    
	[string]$managedFuncName = "";
	try
    {
        $response = GetAmsV2MonitorProperties -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger
		$managedRgName = $response.Response.properties.managedResourceGroupConfiguration.name;
		$logger.LogInfo("Managed RG Name associated with Monitor : $monitorName is $managedRgName");

		$funcDetails = Get-AzResource -ResourceGroupName $managedRgName -Name "$providerName*" -ResourceType Microsoft.Web/sites
		$logger.LogInfo("Function app for Provider $providerName with Monitor : $monitorName is $($funcDetails.Name)");
		$managedFuncName = $funcDetails.Name;
    }
    catch
    {
        $GetProviderErrorMsg = $_.ErrorDetails.ToString();
		$logger.LogError("GetAmsV2ManagedKv : Failed with error: ($($GetProviderErrorMsg.error.code)))", "500", "");
    }

	return @{
		Response = $managedFuncName
		Error = $GetProviderErrorMsg
	}
}
