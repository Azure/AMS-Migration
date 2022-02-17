function Get-AllKeyVaultSecrets($KeyVaultToken, $keyVaultName)
{
    $apiVersion = "2016-10-01"
    return Invoke-RestMethod -Uri "https://$keyVaultName.vault.azure.net/secrets?api-version=$apiVersion" -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}
}