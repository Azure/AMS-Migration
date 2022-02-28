Class ConsoleLogger
{
    [void] LogInfo([string]$message){
        $date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        Write-Host $date " [INFO]" $message
    }

    [void] LogInfoObject([string]$message, [Object]$object){
        Write-Host
        $serialized = $object | ConvertTo-Json -Depth 10
        $date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        Write-Host $date " [INFO]" $message $serialized
    }

    [void] LogWarning([string]$message){
        Write-Host
        $date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        Write-Warning -ForegroundColor Yellow $date " [WARN]" $message
    }

    [void] LogError($message, $errorId, $recommendedAction){
        Write-Host
        $date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        $message = "[ERROR] " + "Message : " + $message + ", ErrorId : " + $errorId + ", Recommended Action : " + $recommendedAction
        Write-Host -ForegroundColor Red $date $message 
    }
    
    [void] LogException([Object]$excp, [string]$message){
        Write-Error "[EXCEPTION]" ConvertTo-Json $excp
        Write-Error "[ERROR]" $message
    }
    
    [void] LogTrace([string]$message){
        if ($global:ENABLE_TRACE -eq $true)
        {
            Write-Host "[TRACE]" $message
        }
    }
}