param(
#[Parameter(Mandatory=$true)]
[string]$subscriptionId = "49d64d54-e966-4c46-a868-1999802b762c",

#[Parameter(Mandatory=$true)]
[string]$tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47",

#[Parameter(Mandatory=$true)]
[string]$providerType = "SapHana",

#[Parameter(Mandatory=$true)]
[string]$amsv1ArmId = "/subscriptions/53990dba-8128-4100-bb6d-ed38861c9f8f/resourceGroups/sakhare_ams_hana/providers/Microsoft.HanaOnAzure/sapMonitors/sakhare_ams4"
)

# ########### Header ###########
# Refer common library file
. $PSScriptRoot\ConsoleLogger.ps1
. $PSScriptRoot\SetCurrentContext.ps1
. $PSScriptRoot\ParseAmsv1ArmId.ps1
. $PSScriptRoot\GetKeyVaultName.ps1
. $PSScriptRoot\ListAllKeyVaultSecrets.ps1
. $PSScriptRoot\KeyVaultRoleAssignment.ps1
. $PSScriptRoot\ListUnsupportedProviders.ps1
. $PSScriptRoot\ListSapHanaProviders.ps1
. $PSScriptRoot\ListSapNetWeaverProviders.ps1
. $PSScriptRoot\GetSecretValue.ps1
# #############################

function Get-Token($typeToken)
{
    $rawToken = Get-AzAccessToken -ResourceTypeName KeyVault
    $token = $rawToken.Token

    return $token
}

function Main
{
    $global:ENABLE_TRACE = $true
    $logger = New-Object ConsoleLogger

    #Uncomment the line below if running on local PowerShell
    #Connect-AzAccount

    $parsedv1ArmId = Get-ParsedArmId $amsv1ArmId
    $logger.LogInfoObject("Parsed AMSv1 ARM id - ", $parsedv1ArmId)

    Set-CurrentContext $parsedv1ArmId.subscriptionId $tenantId

    $KeyVaultToken = Get-Token("KeyVault")

    #Generate the KeyVault Name
    $keyVaultName = Get-KeyVaultName $amsv1ArmId

    # Add role assignment to read secrets from KeyVault
    Add-KeyVaultRoleAssignment $keyVaultName

    # Fetch all the secrets from KeyVault
    $listOfSecrets = Get-AllKeyVaultSecrets $KeyVaultToken $keyVaultName

    $saphanaTransformedList = New-Object System.Collections.ArrayList
    $sapNetWeaverTransformedList = New-Object System.Collections.ArrayList
    $unsupportedProviderList = New-Object System.Collections.ArrayList

    foreach ($i in $listOfSecrets.value)
    {
        if($i.id.Contains('global'))
        {
            continue
        }

        $secret = Get-SecretValue $i.id

        if ($secret.type -like "saphana" -and $providerType -like "saphana")
        {
               if(!$secret.properties.hanaDbPasswordKeyVaultUrl)
               {
                   $settings = $secret.properties

                   #TODO: Transform provider setting
                   $newSettings

                   $request = @{
                        name = $secret.name
                        type = $secret.type
                   }

                   $saphanaTransformedList.Add($request) | Out-Null
                   $logger.LogInfoObject("Adding the following transformed SapHana object to migration list", $request)
               }
               else
               {
                   $request = @{
                        name = $secret.name
                        type = $secret.type
                   }
                   $unsupportedProviderList.Add($request)
                   $logger.LogError("Unsupported Type - SapHana Integrated KeyVault","100", "Please wait for the support to be enabled in AMSv2 to migrate provider - " + $secret.name)
               }
        }
        elseif($secret.type -like "sapnetweaver" -and $providerType -like "sapnetweaver")
        {
            $request = @{
            name = $secret.name
            type = $secret.type
            }

            $sapNetWeaverTransformedList.Add($request) | Out-Null
            $logger.LogInfoObject("Adding the following transformed SapNetWeaver object to migration list", $request)
        }
        else
        {
            $request = @{
            name = $secret.name
            type = $secret.type
            }

            $unsupportedProviderList.Add($request) | Out-Null
        }
    }

    Get-SapHanaProvidersList $saphanaTransformedList
    Get-SapNetWeaverProvidersList $sapNetWeaverTransformedList
    Get-UnsupportedProvidersList $unsupportedProviderList
}

Main