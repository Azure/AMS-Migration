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