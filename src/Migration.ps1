param(
#[Parameter(Mandatory=$true)]
[string]$providerType = $null,

#[Parameter(Mandatory=$true)]
[string]$amsv1ArmId = "<amsv1-arm-id>",

#[Parameter(Mandatory=$true)]
[string]$amsv2ArmId = "<amsv2-arm-id>"
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
Main Entry Function for migration.
#>
function Main
{
    $logger = New-Object ConsoleLogger

	$logger.LogInfo("-----------Setting up Az modules for migration--------------");
	# Install the pre-requisite modules
	InstallModules

    $date = Get-Date -Format "MM-dd-yyyy HH:mm:ss"
	$shortDate = Get-Date -Format "MM-dd-yyyy"
	$shortDate = $shortDate.ToString().Replace(":", "-").Replace(" ", "T");
    $dateStr= $date.ToString().Replace(":", "-").Replace(" ", "T")
    $fileName = "MigrationLog_" + $dateStr
    $logFilePath = Join-Path $PSScriptRoot "\LogFiles\$shortDate\$fileName.txt";
    Start-Transcript -Path $logFilePath

    $logger.LogInfo("-----------Starting migration to AMSv2--------------");

    if($providerType -like $null)
    {
        $providerType = Check-ProviderTypeInput
    }

	$allowedProviders = "saphana", "sapnetweaver", "all";

	if($allowedProviders -notcontains $providerType) {
		$logger.LogError(
			"Provider Type from Parameters $providerType is currently not supported", 
			"500", 
			"Accepted values for Provider Type parameter are saphana, sapnetweaver, all");
		return;
	}

    $logger.LogInfo("Please select an account to connect to Azure Portal...")
    Connect-AzAccount -UseDeviceAuthentication;

    $parsedv1ArmId = Get-ParsedArmId $amsv1ArmId
    $logger.LogInfoObject("Parsed AMSv1 ARM id - ", $parsedv1ArmId)

    Set-CurrentContext -subscriptionId $parsedv1ArmId.subscriptionId -logger $logger;

    # Generate the KeyVault Name
	$logger.LogInfo("Generating key vault name using ams v1 armid.");
    $keyVaultName = Get-KeyVaultName $amsv1ArmId

    # Add role assignment to read secrets from KeyVault
    Add-KeyVaultRoleAssignment -keyVaultName $keyVaultName -logger $logger;

    # Fetch all the secrets from KeyVault
	$logger.LogInfo("Fetch all the secrets from Key Vault $keyVaultName.");
    $listOfSecrets = Get-AzKeyVaultSecret -VaultName $keyVaultName;

	# Parse Netweaver hosts.txt file.
	$sapHostFileEntriesList = ParseSapNetWeaverHostfile -fileName "hosts.txt" -logger $logger;

    $saphanaTransformedList = New-Object System.Collections.ArrayList
    $sapNetWeaverTransformedList = New-Object System.Collections.ArrayList
    $unsupportedProviderList = New-Object System.Collections.ArrayList
	$emptyNwList = New-Object System.Collections.ArrayList
	$isFirstNwProvider = $true

    foreach ($i in $listOfSecrets)
    {
		
        if($i.Name.Contains('global'))
        {
            continue;
        }

        $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $i.Name -AsPlainText;
		$secret = ConvertFrom-Json $secret;

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
                $logger.LogInfoObject("Trying to migrate SapNetWeaver Provider", $secret.name);
				
				$sid = $secret.metadata.sapSid.ToString();
				if(($sid.Length) -eq 0) {
					$logger.LogInfo("Provider $($secret.name) does not have SAP SID");
					$sid = Get-ProviderSapSid -providerName $secret.name -logger $logger;
					$secret.metadata.sapSid = $sid;
				}
				
				if($isFirstNwProvider -eq $true)
				{
					$logger.LogInfo("Setting SapNetWeaver Provider hostfile entry as non-empty for $($secret.name)");
					$logger.LogInfo("Setting SapHostFiles as $($sapHostFileEntriesList)");
					$netweaverMigrationResult = MigrateNetWeaverProvider -secretName $secret.name -secretValue $secret -hostfile $sapHostFileEntriesList -logger $logger
				}
				else 
				{
					$logger.LogInfo("Setting SapNetWeaver Provider hostfile entry as empty for $($secret.name)");
					$netweaverMigrationResult = MigrateNetWeaverProvider -secretName $secret.name -secretValue $secret -hostfile $emptyNwList -logger $logger
				}
				
				$requestNet = @{
                    name = $secret.name
                    type = $secret.type
					state = $netweaverMigrationResult.provisiongState
                }

				if($netweaverMigrationResult.provisiongState -eq "Succeeded"){
					$isFirstNwProvider = $false;
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
			else {
				$logger.LogInfo("Cannot parse the secret value.");
			}
        }
    }

	if ($saphanaTransformedList.Count -gt 0) {
		$logger.LogInfoObject("Migrated AMSv1 SapHana List - ", $saphanaTransformedList);
	}
	
	if ($sapNetWeaverTransformedList.Count -gt 0) {
    	$logger.LogInfoObject("Migrated AMSv1 SapNeWeaver List - ", $sapNetWeaverTransformedList);
	}

	if ($unsupportedProviderList.Count -gt 0) {
    	$logger.LogInfoObject("Not Migrated AMSv1 Unsupported Provider list - ", $unsupportedProviderList);
	}

	$logger.LogInfo("----------- Finished migration to AMSv2 --------------");
	$logger.LogInfo("--------------- Migration Completed ------------------");
    Stop-Transcript

    Get-SapHanaProvidersList $saphanaTransformedList
    Get-SapNetWeaverProvidersList $sapNetWeaverTransformedList
    Get-UnsupportedProvidersList $unsupportedProviderList

	Write-Host "If you are using Cloud Shell, run the below command to download the log file";
	Write-Host -ForegroundColor Yellow "download \LogFiles\$shortDate\$fileName.txt";
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
	Set-AzContext -SubscriptionId $subscriptionId;
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
	Set-AzContext -SubscriptionId $subscriptionId;

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
		return @{
			provisiongState = $provisioningState
		};
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
		
	# we will check the provisioning status for the provider 45 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 45 -and ($provisioningState -like "Accepted" -or $provisioningState -like "Creating")) {

		Start-Sleep -s 20
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState");
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/45) times");
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
	Set-AzContext -SubscriptionId $subscriptionId;

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
		return @{
			provisiongState = $provisioningState
		};
	}

	# trying to delete secret
	# this step is to take care of deleted Successful providers and Failed providers with secret not purged.
	[string]$managedKvName = GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
	[string]$funcName = GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerType $providerType -logger $logger;
	if(($funcName -ne "") -and ($managedKvName -ne "")) {
		[string]$managedSecretName = "sapnetweaver-provider-" + $funcName + "-instance-" + $providerName;
		DeleteAndPurgeSecretFromKeyVault -keyVaultName $managedKvName -secretKey $managedSecretName -logger $logger;
	}

	# call the put provider method.
	PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
		
	# we will check the provisioning status for the provider 45 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 45 -and ($provisioningState -like "Accepted" -or $provisioningState -like "Creating")) {
		Start-Sleep -s 20
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState");
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/45) times");
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