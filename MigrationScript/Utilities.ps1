# Install module pre-requisites
function InstallModules()
{
    try {
        $m = Get-InstalledModule Az -MinimumVersion 5.1.0 -ErrorAction "Stop"
    }
    catch {
    }
    if ($m -eq $null)
    {
        Write-Host -ForegroundColor Green "Installing Az Module."
        Install-Module Az -AllowClobber
        Write-Host -ForegroundColor Green "Installed Az Module."
    }
    else {
        Import-Module Az
        Write-Host -ForegroundColor Green "Importing installed Az Module."
    }

    $m = $null
    try {
        $m = Get-InstalledModule AzureAD -MinimumVersion 2.0.2.61 -ErrorAction "Stop"
    }
    catch {
    }
    if ($m -eq $null)
    {
        Write-Host -ForegroundColor Green "Installing AzureAD Module."
        Install-Module AzureAD
        Write-Host -ForegroundColor Green "Installed AzureAD Module."
    }
    else {
        Import-Module AzureAD
    }
}