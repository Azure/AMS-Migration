param(
#[Parameter(Mandatory=$true)]
[string]$subscriptionId = "49d64d54-e966-4c46-a868-1999802b762c",

#[Parameter(Mandatory=$true)]
[string]$tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47",

#[Parameter(Mandatory=$true)]
[string]$providerType = "sapnetweaver",

#[Parameter(Mandatory=$true)]
[string]$amsv1ArmId = "/subscriptions/53990dba-8128-4100-bb6d-ed38861c9f8f/resourceGroups/DEMO-NEU-SAP-PM1/providers/Microsoft.HanaOnAzure/sapMonitors/demo-neu-sap-monitor",

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
. $PSScriptRoot\Utilities.ps1
# #############################

function Get-Token($typeToken)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName KeyVault
    $token = $rawToken.Token

    return $token
}

function Main
{
	
    $global:ENABLE_TRACE = $true
    $logger = New-Object ConsoleLogger

	$logger.LogInfo("-----------Setting up Az modules for migration--------------")
	# Install the pre-requisite modules
	InstallModules

    $date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
    $dateStr= $date.ToString().Replace(":", "-").Replace(" ", "T")
    $fileName = "MigrationLog_" + $dateStr
    $logFilePath = Join-Path $PSScriptRoot "\$fileName.txt"
    Start-Transcript -Path $logFilePath

    $logger.LogInfo("-----------Starting migration to AMSv2--------------")

    if($providerType -like $null)
    {
        $providerType = Check-ProviderTypeInput
    }

    #Uncomment the line below if running on local PowerShell
	$logger.LogInfo("Please select an account to connect to Azure Portal...")
    Connect-AzAccount

    $parsedv1ArmId = Get-ParsedArmId $amsv1ArmId
    $logger.LogInfoObject("Parsed AMSv1 ARM id - ", $parsedv1ArmId)

    Set-CurrentContext $parsedv1ArmId.subscriptionId $tenantId

    $KeyVaultToken = Get-Token("KeyVault")

    #Generate the KeyVault Name
    $keyVaultName = Get-KeyVaultName $amsv1ArmId

    # Add role assignment to read secrets from KeyVault
    Add-KeyVaultRoleAssignment $keyVaultName

    # Fetch all the secrets from KeyVault
    $listOfSecrets = Get-AllKeyVaultSecrets $KeyVaultToken $keyVaultName

    $saphanaTransformedList = New-Object System.Collections.ArrayList
    $sapNetWeaverTransformedList = New-Object System.Collections.ArrayList
    $unsupportedProviderList = New-Object System.Collections.ArrayList

    foreach ($i in $listOfSecrets.value)
    {
        if($i.id.Contains('global'))
        {
            continue
        }

        $secret = Get-SecretValue $i.id

        if ($secret.type -like "saphana" -and $providerType -like "saphana" -or $providerType -like "all")
        {
				# if the hana provider is using key vault to fetch user credentials, skip the migration. 
				# (To be handled later, once the feature is enabled in ams v2)
               if(!$secret.properties.hanaDbPasswordKeyVaultUrl)
               {                    
					$logger.LogInfoObject("Trying to migrate Provider", $secret.name);
					$hanaMigrationResult = MigrateHanaProvider -secretName $secret.name -secretValue $secret -logger $logger
					if($hanaMigrationResult.provisiongState -eq "Succeeded"){
                     	$logger.LogInfoObject("Adding the following transformed SapHana object to migration list", $request)
					}
					$request = @{
                        name = $secret.name
                        type = $secret.type
						state = $hanaMigrationResult.provisiongState
                    }

                    $saphanaTransformedList.Add($request) | Out-Null
               }
               else
               {
                    $request = @{
                        name = $secret.name
                        type = $secret.type
						state = "Unsupported"
                    }
					
                    $unsupportedProviderList.Add($request) | Out-Null
                    $logger.LogError("Unsupported Type - SapHana Integrated KeyVault","100", "Please wait for the support to be enabled in AMSv2 to migrate provider - " + $secret.name)                  
               }
        }
        elseif($secret.type -like "sapnetweaver" -and $providerType -like "sapnetweaver" -or $providerType -like "all")
        {
            # if the netweaver provider is using key vault to fetch user credentials, skip the migration. 
			# (To be handled later, once the feature is enabled in ams v2)
            if(!$secret.properties.sapPasswordKeyVaultUrl)
            {        
				$str1 = "172.20.164.196 SAPTSTGTMA1 SAPTSTGTMA1.redmond.corp.microsoft.com"
				$str2 = "172.20.164.197 SAPTSTGTMCI SAPTSTGTMCI.redmond.corp.microsoft.com"
				$str3 = "172.20.164.203 SAPTSTGTMA2 SAPTSTGTMA2.redmond.corp.microsoft.com"
				$hostfile = @($str1,$str2,$str3)

                $logger.LogInfoObject("Trying to migrate Provider", $secret.name);
				$netweaverMigrationResult = MigrateNetWeaverProvider -secretName $secret.name -secretValue $secret -hostfile $hostfile -logger $logger
				if($netweaverMigrationResult.provisiongState -eq "Succeeded"){
                    $logger.LogInfoObject("Adding the following transformed SapNetweaver object to migration list", $request)
				}
				$request = @{
                    name = $secret.name
                    type = $secret.type
					state = $netweaverMigrationResult.provisiongState
                }

                $sapNetWeaverTransformedList.Add($request) | Out-Null
            }
            else
               {
                    $request = @{
                        name = $secret.name
                        type = $secret.type
						state = "Unsupported"
                    }
					
                    $unsupportedProviderList.Add($request) | Out-Null
                    $logger.LogError("Unsupported Type - SapNetweaver Integrated KeyVault","101", "Please wait for the support to be enabled in AMSv2 to migrate provider - " + $secret.name)                  
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
	$parsedArmId = Get-ParsedArmId $amsv2ArmId

	[string]$monitorName = $parsedArmId.amsResourceName;
	[string]$resourceGroupName = $parsedArmId.amsResourceGroup;
	[string]$subscriptionId = $parsedArmId.subscriptionId;
	# set context.
	Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId;

	[string]$providerType = $($secretValue.type);
	[string]$providerName = $($secretValue.name) # + (Get-Random -Minimum 2 -Maximum 20000).ToString();
	Write-Host "Provider Name is $($secretValue.name)";
	$providerProperties = $($secretValue.properties)
	$requestObj = @{
		Name = $providerName
		body = @{
			properties = @{
				providerSettings = @{
					providerType = $providerType
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

	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName already exists..");
		Continue;
	}
	elseif ($provisioningState -eq "Failed") {
		$managedKvName = GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
		$funcName = GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerType $providerType -logger $logger;
		# TODO : code to generate the key name 
		# DeleteAndPurgeSecretFromKeyVault -keyVaultName "dummyName" -secretKey "dummyKey"
	}

	# call the put provider method.
	PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
		
	# we will check the provisioning status for the provider 15 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 15 -and $provisioningState -eq "Accepted") {
		Start-Sleep -s 20
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState")
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/15) times.")
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
	$parsedArmId = Get-ParsedArmId $amsv2ArmId

	[string]$monitorName = $parsedArmId.amsResourceName;
	[string]$resourceGroupName = $parsedArmId.amsResourceGroup;
	[string]$subscriptionId = $parsedArmId.subscriptionId;
	# set context.
	Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId;

	[string]$providerType = $($secretValue.type);
	[string]$providerName = $($secretValue.name) # + (Get-Random -Minimum 2 -Maximum 20000).ToString();
	Write-Host "Provider Name is $($secretValue.name)";
	$providerProperties = $($secretValue.properties)
    $metadata = $($secretValue.metadata)
	$requestObj = @{
		Name = $providerName
		body = @{
			properties = @{
				providerSettings = @{
					providerType = "SapNetWeaver"
					sapHostname = $($providerProperties.sapHostName)
					sapSid = $($metadata.sapSid)
					sapInstanceNr = $($providerProperties.sapInstanceNr).ToString()
					sapHostFileEntries = $hostfile
				}
			}
		}
	}

	# check provider status before making a put call
	$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
	$provisioningState = $getResponse.provisiongState;
	$logger.LogInfo("Current Provisioning State : $provisioningState")

	if($provisioningState -eq "Succeeded") {
		$logger.LogInfo("Provider $providerName already exists..");
		Continue;
	}
	elseif ($provisioningState -eq "Failed") {
		$managedKvName = GetAmsV2ManagedKv -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -logger $logger;
		$funcName = GetAmsV2ManagedFunc -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerType $providerType -logger $logger;
		# TODO : code to generate the key name 
		# DeleteAndPurgeSecretFromKeyVault -keyVaultName "dummyName" -secretKey "dummyKey"
	}

	# call the put provider method.
	PutAmsV2Provider -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -request $requestObj -logger $logger;
		
	# we will check the provisioning status for the provider 15 times in 20 sec intervals.
	$checks = 0;

	# default providioning state is accepted, we will keep checking till is changes.
	$provisioningState = "Accepted";
		
	while ($checks -le 15 -and $provisioningState -eq "Accepted") {
		Start-Sleep -s 20
		$getResponse = GetAmsV2ProviderStatus -subscriptionId $subscriptionId -resourceGroup $resourceGroupName -monitorName $monitorName -providerName $providerName -logger $logger;
		$provisioningState = $getResponse.provisiongState;
		$checks += 1;
		$logger.LogInfo("Current Provisioning State : $provisioningState")
		$logger.LogInfo("Checked the status of Put Provider Call ($checks/15) times.")
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