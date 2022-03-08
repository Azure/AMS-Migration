<#
.SYNOPSIS
Function to generate keyvault name using arm id for ams v1 monitor.

.PARAMETER amsv1ArmId
Arm Id for AMS v1.

.EXAMPLE
Get-KeyVaultName -amsv1ArmId $amsv1ArmId 
#>
function Get-KeyVaultName($amsv1ArmId)
{
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($amsv1ArmId)))

    $hashStr = $hash.ToLower() -replace '-', ''
    $length = $hashStr.Length
    $startIdx = $length - 14
    $sapmonId = $hashStr.Substring($startIdx)
    $keyVaultName = "sapmon-kv-" + $sapmonId
    $logger.LogInfo("Fetching secrets from KeyVault - " + $keyVaultName)

    return $keyVaultName
}

<#
.SYNOPSIS
Function to get all secrets from keyvault.

.PARAMETER KeyVaultToken
jwt token.

.PARAMETER keyVaultName
Keyvault name.

.EXAMPLE
Get-AllKeyVaultSecrets -KeyVaultToken $KeyVaultToken -keyVaultName $keyVaultName;
#>
function Get-AllKeyVaultSecrets([string]$KeyVaultToken, [string]$keyVaultName)
{
    [string]$apiVersion = "2016-10-01"
    return Invoke-RestMethod -Uri "https://$keyVaultName.vault.azure.net/secrets?api-version=$apiVersion" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}
}

<#
.SYNOPSIS
Function to add role assignments to keyvault
It adds List, Get, Set, Delete, Purge Permissions for Secrets.

.PARAMETER keyVaultName
Keyvault Name.

.PARAMETER logger
Logger Object.

.EXAMPLE
$logger = New-Object ConsoleLogger
Add-KeyVaultRoleAssignment -keyVaultName $keyVaultName -logger $logger;
#>
function Add-KeyVaultRoleAssignment([string]$keyVaultName, $logger)
{
	try {
		$currentUser = Get-AzContext | ConvertTo-Json | ConvertFrom-Json;
		$logger.LogInfo("Current Principle Name is : $($currentUser.Account.Id)");
		Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -UserPrincipalName $currentUser.Account.Id  -PermissionsToSecrets List,Get,Set,Delete,Purge
		$logger.LogInfo("Added Access Policy for User $($currentUser.Account.Id) in Keyvault $keyVaultName");
	}
	catch {
		$addPolicyError = $_.exception.message
		throw "Add-KeyVaultRoleAssignment, Failed with error: ($addPolicyError)";
	}
}

<#
.SYNOPSIS
Function to get a secret from keyvault.

.PARAMETER uri
Secret uri.

.PARAMETER keyVaultToken
jwt token.

.EXAMPLE
An example
#>
function Get-SecretValue([string]$uri, [string]$keyVaultToken)
{
    [string]$newUri = $i.id + "?api-version=2016-10-01"
	$secretValue = Invoke-RestMethod -Uri $newUri -Method GET -Headers @{Authorization="Bearer $keyVaultToken"}
	$parsed = $secretValue.value | ConvertFrom-Json

    return $parsed
}

<#
.SYNOPSIS
Function to get a delete and purge a secret from keyvault.

.PARAMETER keyVaultName
Key vault name.

.PARAMETER secretKey
Secret name to be retrieved from key vault. 

.EXAMPLE
DeleteAndPurgeSecretFromKeyVault -keyVaultName $keyVaultName -secretKey $name -logger $logger;
#>
function DeleteAndPurgeSecretFromKeyVault([string]$keyVaultName, [string]$secretKey, $logger) {
	try {
		# Add-KeyVaultRoleAssignment -keyVaultName $keyVaultName -logger $logger;
		Remove-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretKey -PassThru -Force -ErrorAction SilentlyContinue;
		$logger.LogInfo("Deleted Secret $secretKey from Keyvault $keyVaultName, Sleeping for 15s");
		Start-Sleep -s 15
		Remove-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretKey -InRemovedState -PassThru -Force -ErrorAction SilentlyContinue;
		$logger.LogInfo("Purged Secret $secretKey from Keyvault $keyVaultName");
		Start-Sleep -s 10
		return $true;
	} catch {
		$deleteerrMsg = $_.exception.message
		throw "DeleteAndPurgeSecretFromKeyVault, Failed with error: ($deleteerrMsg)";
	}
}