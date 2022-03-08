<#
.SYNOPSIS
Function to get alerts inside a Resource Group.

.PARAMETER SubscriptionId
the SubscriptionId.

.PARAMETER ResourceGroupName
the ResourceGroupName.

.PARAMETER logger
logger object.

.EXAMPLE
. $PSScriptRoot\ConsoleLogger.ps1
$logger = New-Object ConsoleLogger
$x = GetAlerts -SubscriptionId $subscriptionId -ResourceGroupName $rgName -logger $logger;
#>
function GetAlerts([string]$SubscriptionId, [string]$ResourceGroupName, $logger) {
	
	# get token for the current user.
	$rawToken = Get-AzAccessToken -ResourceTypeName Arm;
    $armToken = $rawToken.Token;
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    }

	[string]$apiVersion = "2021-08-01";
	[string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $SubscriptionId;
	[string]$rgParams = "/resourceGroups/" + $ResourceGroupName;
	[string]$providerParams = "/providers/Microsoft.Insights/scheduledQueryRules?api-version=$apiVersion";
	$url = $url + $subscriptionParams + $rgParams + $providerParams;

	try
    {
        $response = Invoke-RestMethod -Method 'get' -Uri $url -Headers $headers;
    }
    catch
    {
        $GetAlertsErrorMsg = $_.ErrorDetails.ToString();
		$logger.LogInfo("GetAlerts failed with error : ($($GetAlertsErrorMsg)))");
    }

	return @{
		Response = $response
		Error = $GetAlertsErrorMsg
	};
}

<#
.SYNOPSIS
Function to create an alert in a resource group in LAWS.


.PARAMETER SubscriptionId
the SubscriptionId.

.PARAMETER ResourceGroupName
the ResourceGroupName.

.PARAMETER alertName
name of the alert.

.PARAMETER request
request object.

.PARAMETER logger
logger object.

.EXAMPLE
An example
#>
function PutAlert([string]$subscriptionId, [string]$resourceGroup, [string]$alertName, $request, $logger) {
	$rawToken = Get-AzAccessToken -ResourceTypeName Arm;
    $armToken = $rawToken.Token;

	$headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    };

    $bodyStr = $request.body | ConvertTo-Json -Depth 5;
	[string]$apiVersion = "2021-08-01";
	[string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $SubscriptionId;
	[string]$rgParams = "/resourceGroups/" + $ResourceGroupName;
	[string]$providerParams = "/providers/Microsoft.Insights/scheduledQueryRules/$alertName?api-version=$apiVersion";
	$url = $url + $subscriptionParams + $rgParams + $providerParams;

	$url = $url + $subscriptionParams + $rgParams + $providerParams;

	$logger.LogInfo("Making Put Alert call with $url")
	try
    {
        $response = Invoke-RestMethod -Method 'Put' -Uri $url -Headers $headers -Body $bodyStr
    }
    catch
    {
        $putAlertErrorMsg = $_.ErrorDetails | ConvertTo-Json -Depth 10;
		$logger.LogInfo("PutAlert failed with error: ($($putAlertErrorMsg))");
    }

	return @{
		Response = $response
		Error = $putAlertErrorMsg
	}
}