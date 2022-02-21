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
