function Get-UnsupportedProvidersList($unsupportedProviderList)
{
    $width = 25
    Write-Host
    Write-Host
    Write-Host "Listing unsupported provider(s)"
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($unsupportedProvider in $unsupportedProviderList)
    {
        Write-Host -NoNewline "    " $unsupportedProvider.name
        $spaces = $width - $unsupportedProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $unsupportedProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}