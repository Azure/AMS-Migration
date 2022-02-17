function Get-SapHanaProvidersList($saphanaTransformedList)
{
    $width = 25
    Write-Host
    Write-Host
    Write-Host "Listing migrating SapHana provider(s)"
    Write-Host -ForegroundColor Magenta "     NAME                                         TYPE"
    Write-Host "|-------------------------------------------------------------------|"
    foreach ($saphanaProvider in $saphanaTransformedList)
    {
        Write-Host -NoNewline "    " $saphanaProvider.name
        $spaces = $width - $saphanaProvider.name.Length + 4
        for($i=0; $i -lt $spaces; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host -NoNewline      "|"

        for($i=0; $i -lt $width - 10; $i++)
        {
            Write-Host -NoNewline " "
        }
        Write-Host $saphanaProvider.type
    }
    Write-Host "|-------------------------------------------------------------------|"
}