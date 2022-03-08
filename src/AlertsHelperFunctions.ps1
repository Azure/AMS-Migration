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

	[string]$apiVersion = "2018-04-16";
	[string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $SubscriptionId;
	[string]$rgParams = "/resourceGroups/" + $ResourceGroupName;
	[string]$providerParams = "/providers/Microsoft.Insights/scheduledQueryRules?api-version=$apiVersion";
	$url = $url + $subscriptionParams + $rgParams + $providerParams;
	$logger.LogInfo($url);
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
function PutAlert([string]$subscriptionId, [string]$ResourceGroupName, [string]$alertName, $request, $logger) {
	$rawToken = Get-AzAccessToken -ResourceTypeName Arm;
    $armToken = $rawToken.Token;

	$headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $armToken"
    };

    $bodyStr = $request | ConvertTo-Json -Depth 10;
    $bodyStr = $bodyStr.Replace("\u0027", "'");
    # Write-Host $bodyStr;
	[string]$apiVersion = "2018-04-16";
	[string]$url = "https://management.azure.com/";
	[string]$subscriptionParams = "subscriptions/" + $SubscriptionId;
	[string]$rgParams = "/resourceGroups/" + $ResourceGroupName;
	[string]$providerParams = "/providers/Microsoft.Insights/scheduledQueryRules/" + $alertName + "?api-version=" + $apiVersion;
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

function MigrateLawsAlerts($LawsDetails, $providerType, $logger) {
    $amsv1LawsDetails = Get-ParsedArmId($LawsDetails.amsv1LawsId);
    $amsv2LawsDetails = Get-ParsedArmId($LawsDetails.amsv2LawsId);

    $response = GetAlerts -SubscriptionId $amsv1LawsDetails.subscriptionId -ResourceGroupName $amsv1LawsDetails.amsResourceGroup -logger $logger;
    $alertsArray = $response.Response.value;
    if($alertsArray.Count -ne 0) {
        foreach($alert1 in $alertsArray) {
            [string]$alertName = $($alert1.name);
            $alert1.properties.source.dataSourceId = $LawsDetails.amsv2LawsId;
			$alert1.id = $LawsDetails.amsv2LawsId;

            if($providerType -like "all")
            {
                PutAlert -subscriptionId $amsv2LawsDetails.subscriptionId -resourceGroup $amsv2LawsDetails.amsResourceGroup -alertName $alertName -request $alert1 -logger $logger;
            }
            elseif(($providerType -like "saphana") -and ($alert1.tags.'alert-template-id'.Contains("saphana")))
            {
                PutAlert -subscriptionId $amsv2LawsDetails.subscriptionId -resourceGroup $amsv2LawsDetails.amsResourceGroup -alertName $alertName -request $alert1 -logger $logger;
                $logger.LogInfo("Migrating SapHana Alert - $($alertName))");
            }
            elseif(($providerType -like "sapnetweaver") -and ($alert1.tags.'alert-template-id'.Contains("sapnetweaver")))
            {
                PutAlert -subscriptionId $amsv2LawsDetails.subscriptionId -resourceGroup $amsv2LawsDetails.amsResourceGroup -alertName $alertName -request $alert1 -logger $logger;
                $logger.LogInfo("Migrating SapNetWeaver Alert - $($alertName))");
            }
            else
            {
                $logger.LogInfo("Unsupported Alert Migration for - $($alertName))");
            }
        }
    }
	else {
		$logger.LogInfo("No alerts found inside ams v1 resource.");
	}
}
