Class ConsoleLogger
{
    [void] LogInfo([string]$message){
        Write-Host "[INFO]" $message
    }

    [void] LogInfoObject([string]$message, [Object]$object){
        Start-Transcript -Path .\testlog.txt
        $serialized = $object | ConvertTo-Json -Depth 10
        Write-Host "[INFO]" $message $serialized 
        Stop-Transcript
    }

    [void] LogWarning([string]$message){
        Write-Warning -ForegroundColor Yellow "[WARN]" $message
    }

    [void] LogError($message, $errorId, $recommendedAction){
        $message = "[ERROR] " + "Message : " + $message + ", ErrorId : " + $errorId + ", Recommended Action : " + $recommendedAction
        Write-Host -ForegroundColor Red $message 
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