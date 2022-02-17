function Get-ParsedArmId($armId)
{
    $CharArray =$armId.Split("/")
    $i=2

    $parsedInput = @{
        subscriptionId = $CharArray[$i]
        amsV1ResourceGroup = $CharArray[$i+2]
        amsv1ResourceName = $CharArray[$CharArray.Length-1]
    }

    return $parsedInput
}