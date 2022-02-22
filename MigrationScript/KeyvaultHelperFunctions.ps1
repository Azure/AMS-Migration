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

function Get-AllKeyVaultSecrets($KeyVaultToken, $keyVaultName)
{
    $apiVersion = "2016-10-01"
    return Invoke-RestMethod -Uri "https://$keyVaultName.vault.azure.net/secrets?api-version=$apiVersion" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}
}

function Add-KeyVaultRoleAssignment($keyVaultName)
{
    $currentUser = Get-AzContext | ConvertTo-Json | ConvertFrom-Json
    $currentUserId = $currentUser.Account.Id

    $objectId = Get-AzAdUser -UserPrincipalName $currentUserId

    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $objectId.Id  -PermissionsToSecrets List,Get,Set,Delete,Purge
}

function Get-SecretValue($uri)
{
    $newUri = $i.id + "?api-version=2016-10-01"
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
DeleteAndPurgeSecretFromKeyVault -keyVaultName $keyVaultName -secretKey $name
#>
function DeleteAndPurgeSecretFromKeyVault([string]$keyVaultName, [string]$secretKey) {
	try {
		Add-KeyVaultRoleAssignment -keyVaultName $keyVaultName;
		Remove-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretKey -PassThru -Force
		Start-Sleep -s 15
		Remove-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretKey -InRemovedState -PassThru -Force;
		return $true;
	} catch {
		$deleteerrMsg = $_.exception.message
		throw "DeleteAndPurgeSecretFromKeyVault, Failed with error: ($deleteerrMsg)";
	}
}