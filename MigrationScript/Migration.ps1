param(
#[Parameter(Mandatory=$true)]
[string]$subscriptionId = "49d64d54-e966-4c46-a868-1999802b762c",

#[Parameter(Mandatory=$true)]
[string]$tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47",

#[Parameter(Mandatory=$true)]
[string]$providerType = "sapnetweaver",

#[Parameter(Mandatory=$true)]
[string]$amsv1ArmId = "/subscriptions/49d64d54-e966-4c46-a868-1999802b762c/resourceGroups/rg-ams-migration-test/providers/Microsoft.HanaOnAzure/sapMonitors/ams-v1-migration-netweaver",

#[Parameter(Mandatory=$true)]
[string]$amsv2ArmId = "/subscriptions/49d64d54-e966-4c46-a868-1999802b762c/resourceGroups/rg-ams-migration-test/providers/Microsoft.Workloads/monitors/ams-migration-test"
)

# ########### Header ###########
# Refer common library file
. $PSScriptRoot\ConsoleLogger.ps1
. $PSScriptRoot\KeyvaultHelperFunctions.ps1
. $PSScriptRoot\UtilityFunctions.ps1
. $PSScriptRoot\ProviderTypePrompt.ps1
. $PSScriptRoot\AmsOperationsHelper.ps1
. $PSScriptRoot\Constants.ps1
# #############################

<#
.SYNOPSIS
Function to fetch jwt token for key vault.

.PARAMETER typeToken
keyvault token.

.EXAMPLE
Get-Token("KeyVault")
#>
function Get-Token([string]$typeToken)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName $typeToken;
    $token = $rawToken.Token;
    return $token
}

<#
.SYNOPSIS
Main Entry Function for migration.
#>
function Main
{
    $global:ENABLE_TRACE = $true
    $logger = New-Object ConsoleLogger

	$logger.LogInfo("-----------Setting up Az modules for migration--------------")
	# Install the pre-requisite modules
	InstallModules

    $date = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
	$shortDate = Get-Date -Format "MM-dd-yyyy"
	$shortDate = $shortDate.ToString().Replace(":", "-").Replace(" ", "T");
    $dateStr= $date.ToString().Replace(":", "-").Replace(" ", "T")
    $fileName = "MigrationLog_" + $dateStr
    $logFilePath = Join-Path $PSScriptRoot "\LogFiles\$shortDate\$fileName.txt";
    Start-Transcript -Path $logFilePath

    $logger.LogInfo("-----------Starting migration to AMSv2--------------")

    if($providerType -like $null)
    {
        $providerType = Check-ProviderTypeInput
    }

    $logger.LogInfo("Please select an account to connect to Azure Portal...")
    Connect-AzAccount

    $parsedv1ArmId = Get-ParsedArmId $amsv1ArmId
    $logger.LogInfoObject("Parsed AMSv1 ARM id - ", $parsedv1ArmId)

    Set-CurrentContext $parsedv1ArmId.subscriptionId $tenantId -logger $logger;

	$logger.LogInfo("Generating JWT token to access keyvault.");
    $KeyVaultToken = Get-Token("KeyVault")

    #Generate the KeyVault Name
	$logger.LogInfo("Generating key vault name using ams v1 armid.");
    $keyVaultName = Get-KeyVaultName $amsv1ArmId

    # Add role assignment to read secrets from KeyVault
    Add-KeyVaultRoleAssignment -keyVaultName $keyVaultName -logger $logger;

    # Fetch all the secrets from KeyVault
	$logger.LogInfo("Fetch all the secrets from Key Vault $keyVaultName.");
    $listOfSecrets = Get-AllKeyVaultSecrets -KeyVaultToken $KeyVaultToken -keyVaultName $keyVaultName

    $saphanaTransformedList = New-Object System.Collections.ArrayList
    $sapNetWeaverTransformedList = New-Object System.Collections.ArrayList
    $unsupportedProviderList = New-Object System.Collections.ArrayList

	if($providerType -notlike "saphana" -and $providerType -notlike "all" -and $providerType -notlike "sapnetweaver") {
		$logger.LogError(
			"Provider Type from Parameters $providerType is currently not supported", 
			"500", 
			"Accepted values for Provider Type parameter are saphana, sapnetweaver, all");
	}

    foreach ($i in $listOfSecrets.value)
    {
        if($i.id.Contains('global'))
        {
            continue
        }

        $secret = Get-SecretValue -uri $i.id -keyVaultToken $KeyVaultToken

        if ($secret.type -like "saphana" -and ($providerType -like "saphana" -or $providerType -like "all"))
        {
			# if the hana provider is using key vault to fetch user credentials, skip the migration. 
			# (To be handled later, once the feature is enabled in ams v2)
			if(!$secret.properties.hanaDbPasswordKeyVaultUrl)
			{                  
				$logger.LogInfoObject("Trying to migrate SapHana Provider", $secret.name);
				$hanaMigrationResult = MigrateHanaProvider -secretName $secret.name -secretValue $secret -logger $logger

				$requestHana = @{
					name = $secret.name
					type = $secret.type
					state = $hanaMigrationResult.provisiongState
				}

				if($hanaMigrationResult.provisiongState -eq "Succeeded"){
					$logger.LogInfoObject("Adding the following transformed SapHana object to migration list", $requestHana)
				}

				$saphanaTransformedList.Add($requestHana) | Out-Null
			}
			else
			{
				$request = @{
					name = $secret.name
					type = $secret.type
					state = "Unsupported"
				}
				
				$unsupportedProviderList.Add($request) | Out-Null
				$logger.LogError("Unsupported Type - SapHana Integrated KeyVault",
					"100",
					"Please wait for the support to be enabled in AMSv2 to migrate provider - " + $secret.name)                  
			}
        }
        elseif($secret.type -like "sapnetweaver" -and ($providerType -like "sapnetweaver" -or $providerType -like "all"))
        {
            # if the netweaver provider is using key vault to fetch user credentials, skip the migration. 
			# and if the provider is a RFC SAP Netweaver provider then skip the migration. 
			# (To be handled later, once the feature is enabled in ams v2)
            if(!$secret.properties.sapPasswordKeyVaultUrl -and !$secret.properties.sapRfcSdkBlobUrl)
            {
				$hashTable = ParseSapNetWeaverHostfile -fileName "hosts.json" -logger $logger;

                $logger.LogInfoObject("Trying to migrate SapNetWeaver Provider", $secret.name);

				if(!$hashTable.ContainsKey($secret.name))
				{
					$hashTable.Add($secret.name, @());
					$logger.LogInfo("Provider $($secret.name) not found in hosts file. Setting empty hostfile entry[]");
				}

				$netweaverMigrationResult = MigrateNetWeaverProvider -secretName $secret.name -secretValue $secret -hostfile $hashTable[$secret.name] -logger $logger

				$requestNet = @{
                    name = $secret.name
                    type = $secret.type
					state = $netweaverMigrationResult.provisiongState
                }

				if($netweaverMigrationResult.provisiongState -eq "Succeeded"){
                    $logger.LogInfoObject("Adding the following transformed SapNetweaver object to migration list", $requestNet)
				}

                $sapNetWeaverTransformedList.Add($requestNet) | Out-Null
            }
            else
               {
                    $request = @{
                        name = $secret.name
                        type = $secret.type
						state = "Unsupported"
                    }
					
                    $unsupportedProviderList.Add($request) | Out-Null
                    $logger.LogError("Unsupported Type - SapNetweaver Integrated KeyVault or RFC",
						"101",
						"Please wait for the support to be enabled in AMSv2 to migrate provider - " + $secret.name)                  
               }
        }
        else
        {
            if($secret.type -notlike "sapnetweaver" -and $secret.type -notlike "saphana")
            {
                $request = @{
					name = $secret.name
					type = $secret.type
                }
                
                $unsupportedProviderList.Add($request) | Out-Null
            }
        }
    }

    Stop-Transcript

    Get-SapHanaProvidersList $saphanaTransformedList
    Get-SapNetWeaverProvidersList $sapNetWeaverTransformedList
    Get-UnsupportedProvidersList $unsupportedProviderList

    Start-Transcript -Append -Path $logFilePath

    $logger.LogInfoObject("Migrated AMSv1 SapHana List - ", $saphanaTransformedList)
    $logger.LogInfoObject("Migrated AMSv1 SapNeWeaver List - ", $sapNetWeaverTransformedList)
    $logger.LogInfoObject("Not Migrated AMSv1 Unsupported Provider list - ", $unsupportedProviderList)

	$logger.LogInfo("-----------Finishing migration to AMSv2--------------")
    Stop-Transcript
}

<#
.SYNOPSIS
Function get the Provider state in AMS v1

.PARAMETER providerName
Provider Name 

.EXAMPLE
GetProviderV1ProvisioningState -providerName $providerName;
#>
function GetProviderV1ProvisioningState([string]$providerName, $logger) {
	# checking provider state in ams v1.
	$parsedArmId = Get-ParsedArmId $amsv1ArmId
	[string]$monitorName = $parsedArmId.amsResourceName;
	[string]$resourceGroupName = $parsedArmId.amsResourceGroup;
	[string]$subscriptionId = $parsedArmId.subscriptionId;
	
	# set context.
	Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId;
	$logger.LogInfo("Checking provisioning state for provider $providerName in AMS v1.");
	[string]$v1State = GetAmsV1ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $MonitorName -providerName $providerName -logger $logger;
	$logger.LogInfo("Provisioning State in AMS v1 : $v1State");
	return $v1State;
}

<#
.SYNOPSIS
Function to migrate the Hana Providers to ams v2

.PARAMETER secretName
Secret Name, this contains the name of the provider. 

.PARAMETER secretValue
Secret Value, this contains the provider configuration.

.PARAMETER logger
logger object.

.EXAMPLE
MigrateHanaProvider -secretName $secret.name -secretValue $secret -logger $logger
#>
function MigrateHanaProvider([string]$secretName, $secretValue, $logger) {
	
	[string]$providerType = $($secretValue.type);
	[string]$providerName = $($secretValue.name);

	$v1HanaState = GetProviderV1ProvisioningState -providerName $providerName -logger $logger;
	if($v1HanaState[1] -like "Failed") {
		$logger.LogInfo("Provider $providerName is in Failed state in AMS v1. Skipping migration.");
		return @{
			provisiongState = "Skipped"
		}
	}

	$parsedArmId = Get-ParsedArmId $amsv2ArmId

	[string]$monitorName = $parsedArmId.amsResourceName;
	[string]$resourceGroupName = $parsedArmId.amsResourceGroup;
	[string]$subscriptionId = $parsedArmId.subscriptionId;
	# set context.
	Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId;

	$providerProperties = $($secretValue.properties)
	$requestObj = @{
		Name = $providerName
		body = @{
			properties = @{
				providerSettings = @{
					providerType = $hanaProviderType
					hostname = $($providerProperties.hanaHostname)
					dbName = $($providerProperties.hanaDbName)
					sqlPort = $($providerProperties.hanaDbSqlPort).ToString()
					dbUsername = $($providerProperties.hanaDbUsername)
					dbPassword = $($providerProperties.hanaDbPassword)
				}
			}
		}
	}

	# check provider status before making a put call
	$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
	$provisioningState = $getResponse.provisiongState;
	$logger.LogInfo("Current Provisioning State : $provisioningState")

	# if the Provider already exists then proceed with no action.
	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName already exists..");
		Continue;
	}

	# trying to delete secret
	# this step is to take care of deleted Successful providers and Failed providers with secret not purged.
	[string]$managedKvName = GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
	[string]$funcName = GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerType $providerType -logger $logger;
	if($funcName.Length -gt 0 -and $managedKvName.Length -gt 0) {
		[string]$managedSecretName = "saphana-provider-" + $funcName + "-instance-" + $providerName;
		DeleteAndPurgeSecretFromKeyVault -keyVaultName $managedKvName -secretKey $managedSecretName -logger $logger;
	}

	# call the put provider method.
	PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
		
	# we will check the provisioning status for the provider 15 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 30 -and ($provisioningState -like "Accepted" -or $provisioningState -like "Creating")) {

		Start-Sleep -s 30
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState");
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/30) times");
	}

	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName created successfully..");
	}
	elseif($provisioningState -eq "Failed") {
		$logger.LogInfo("Provider $providerName creation failed..");
	}

	return @{
		provisiongState = $provisioningState
	}
}

<#
.SYNOPSIS
Function to create SAP Netweaver request body for PUT calls.

.PARAMETER providerProperties
SAP Netweaver Provider Properties (hostname, instance number etc.).

.PARAMETER metadata
Provider metadata (SID)

.PARAMETER hostfile
host file entries for SAP Netweaver Provider.

.EXAMPLE
SetNetweaverRequestBody -providerProperties $providerProperties -metadata $metadata -hostfile $hostfile
#>
function SetNetweaverRequestBody($providerProperties, $metadata, $hostfile)
{
	$subDomain = ""
	if($($providerProperties.sapSubdomain) -notlike $null)
	{
		$subDomain = "." + $($providerProperties.sapSubdomain)
	}

	$requestObj = @{
		Name = $providerName
		body = @{
			properties = @{
				providerSettings = @{
					providerType = $netweaverProviderType
					sapHostname = $($providerProperties.sapHostName) + $subDomain
					sapSid = $($metadata.sapSid)
					sapInstanceNr = $($providerProperties.sapInstanceNr).ToString()
					sapHostFileEntries = $hostfile
				}
			}
		}
	}

	return $requestObj
}

<#
.SYNOPSIS
Function to migrate the Hana Providers to ams v2

.PARAMETER secretName
Secret Name, this contains the name of the provider. 

.PARAMETER secretValue
Secret Value, this contains the provider configuration.

.PARAMETER hostfile
hostfile object.

.PARAMETER logger
logger object.

.EXAMPLE
MigrateNetWeaverProvider -secretName $secret.name -secretValue $secret -logger $logger
#>
function MigrateNetWeaverProvider([string]$secretName, $secretValue, $hostfile, $logger) {
	
	[string]$providerType = $($secretValue.type);
	[string]$providerName = $($secretValue.name);

	$v1HanaState = GetProviderV1ProvisioningState -providerName $providerName -logger $logger;
	if($v1HanaState[1] -like "Failed") {
		$logger.LogInfo("Provider $providerName is in Failed state in AMS v1. Skipping migration.");
		return @{
			provisiongState = "Skipped"
		}
	}
	$parsedArmId = Get-ParsedArmId $amsv2ArmId

	[string]$monitorName = $parsedArmId.amsResourceName;
	[string]$resourceGroupName = $parsedArmId.amsResourceGroup;
	[string]$subscriptionId = $parsedArmId.subscriptionId;
	# set context.
	Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId;

	$providerProperties = $($secretValue.properties)
    $metadata = $($secretValue.metadata)
	$requestObj = SetNetweaverRequestBody -providerProperties $providerProperties -metadata $metadata -hostfile $hostfile

	# check provider status before making a put call
	$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
	$provisioningState = $getResponse.provisiongState;
	$logger.LogInfo("Current Provisioning State : $provisioningState")

	# if the Provider already exists then proceed with no action.
	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName already exists..");
		Continue;
	}

	# trying to delete secret
	# this step is to take care of deleted Successful providers and Failed providers with secret not purged.
	[string]$managedKvName = GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
	[string]$funcName = GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerType $providerType -logger $logger;
	if(($funcName -ne "") -and ($managedKvName -ne "")) {
		[string]$managedSecretName = "saphana-provider-" + $funcName + "-instance-" + $providerName;
		DeleteAndPurgeSecretFromKeyVault -keyVaultName $managedKvName -secretKey $managedSecretName -logger $logger;
	}

	# call the put provider method.
	PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
		
	# we will check the provisioning status for the provider 15 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 30 -and ($provisioningState -like "Accepted" -or $provisioningState -like "Creating")) {
		Start-Sleep -s 30
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState");
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/30) times");
	}

	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName created successfully..");
	}
	elseif($provisioningState -eq "Failed") {
		$logger.LogInfo("Provider $providerName creation failed..");
	}

	return @{
		provisiongState = $provisioningState
	}
}

Main