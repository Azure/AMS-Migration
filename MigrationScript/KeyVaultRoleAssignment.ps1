function Add-KeyVaultRoleAssignment($keyVaultName)
{
    $currentUser = Get-AzContext | ConvertTo-Json | ConvertFrom-Json
    $currentUserId = $currentUser.Account.Id

    $objectId = Get-AzAdUser -UserPrincipalName $currentUserId

    Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $objectId.Id  -PermissionsToSecrets List,Get
}