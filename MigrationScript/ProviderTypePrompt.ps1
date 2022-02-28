function Check-ProviderTypeInput
{
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Warning
    $MessageBody = "You have not added specific provider tag. Are you sure you want to migrate all the supported providers?"
    $MessageTitle = "Confirm Provider type"

    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)

    Write-Host "Your choice is $Result"

    $providerType = "All"
    if($Result -like "yes")
    {
        $logger.LogInfo("Migrating all supported provider types - [SapHana and SapNetWeaver (soap)]")
    }
    else
    {
        $providerType = Read-Host -Prompt 'Input your provider type to migrate'
        $logger.LogInfo("Migrating provider type - " + $providerType)
    }

    return $providerType
}

function Get-ProviderSapSid([string]$providerName, $logger)
{
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    # $MessageIcon = [System.Windows.MessageBoxImage]::Warning
    [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
 
	[string]$sapSid = "";
	while ($sapSid.Length -lt 3) {
		[string]$messageTitle = 'Enter SAP SID'
		[string]$dialogContent = "SAP SID property not found for provider $providerName." + "`n`n" +
		"Please enter a 3 letter SAP SID for provider $providerName"
		$sapSid = [Microsoft.VisualBasic.Interaction]::InputBox($dialogContent, $messageTitle);
	}
	$sapSid = $sapSid.ToUpper();
	$sapSid = $sapSid.Substring(0,3);
    $logger.LogInfo("For provider $providerName, User entered SAP SID : $($sapSid)");
    return $sapSid;
}

