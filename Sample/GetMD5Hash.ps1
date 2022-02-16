$someString = "/subscriptions/53990dba-8128-4100-bb6d-ed38861c9f8f/resourceGroups/sakhare_ams_hana/providers/Microsoft.HanaOnAzure/sapMonitors/sakhare_ams4"
$md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$utf8 = New-Object -TypeName System.Text.UTF8Encoding
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($someString)))

$hashStr = $hash.ToLower() -replace '-', ''
$length = $hashStr.Length
$startIdx = $length - 14
$sapmonId = $hashStr.Substring($startIdx)
echo $sapmonId
