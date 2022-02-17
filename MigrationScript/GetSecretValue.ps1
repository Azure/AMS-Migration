function Get-SecretValue($uri)
{
    $newUri = $i.id + "?api-version=2016-10-01"
	$secretValue = Invoke-RestMethod -Uri $newUri -Method GET -Headers @{Authorization="Bearer $keyVaultToken"}
	$parsed = $secretValue.value | ConvertFrom-Json

    return $parsed
}