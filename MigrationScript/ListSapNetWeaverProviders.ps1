function Get-SapNetWeaverProvidersList($sapNetWeaverTransformedList)
{
    $width = 25
    Write-Host
    Write-Host
    Write-Host "Listing migrating SapNetWeaver provider(s)"
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($sapNetWeaverProvider in $sapNetWeaverTransformedList)
    {
        Write-Host -NoNewline "    " $sapNetWeaverProvider.name
        $spaces = $width - $sapNetWeaverProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $sapNetWeaverProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}