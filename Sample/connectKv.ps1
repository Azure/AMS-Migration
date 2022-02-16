Get-AzSubscription -SubscriptionId "53990dba-8128-4100-bb6d-ed38861c9f8f" -TenantId "72f988bf-86f1-41af-91ab-2d7cd011db47" | Set-AzContext
#Connect-AzAccount
#$Response = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Method GET -Headers @{Metadata="true"}

#Another way to get token for Amr and KeyVault.
$s = Get-AzAccessToken -ResourceTypeName KeyVault
#echo $s.Token

#$KeyVaultToken = $Response.access_token
$KeyVaultToken = $s.Token

#$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&client_id=16f49885-d857-4b09-9381-d8cd70588524&resource=https://management.azure.com/' -Method GET -Headers @{Metadata="true"}
#$content = $response.Content | ConvertFrom-Json
#$ArmToken = $content.access_token

#Get all secrets from keyvault
#$res = Invoke-RestMethod -Uri https://sapmon-kv-c59e0bdb39ff9a.vault.azure.net/secrets?api-version=2016-10-01 -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}

$res = Invoke-RestMethod -Uri https://sapmon-kv-c59e0bdb39ff9a.vault.azure.net/secrets/haprov61?api-version=2016-10-01 -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}
$parsed = $res.value| ConvertFrom-Json
$settings = $parsed.properties

foreach ($i in $res.value)
{
	if(!$i.id.Contains('global')) {
        $newUri = $i.id + "?api-version=2016-10-01"
		 $res2 = Invoke-RestMethod -Uri $newUri -Method GET -Headers @{Authorization="Bearer $KeyVaultToken"}
		 $parsed = $res2.value| ConvertFrom-Json
		 $settings = $parsed.properties
		
		echo $settings
	}
}

