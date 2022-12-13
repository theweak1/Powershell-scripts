param($File)
#----- define folder where files are located -----#

$currentDir = Get-Location
$LogFile = "$currentDir\DeleteScript_log.txt"

function WriteLog
{
    [CmdletBinding()]
    Param ([string]$LogString)
    $Stamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    $LogMessage = "$Stamp -> $Logstring"
    
    If($LogFile) {
        Add-Content $LogFile -value $LogMessage
    }
    Else {
        Write-Output $LogMessage
    }
}

$TargetFolders = Get-Content $File

    
$TargetFolders | ForEach-Object {
    $validPath = Test-Path $_ 
    
    if($validPath -eq $True)
    {
        $scriptblock = {
            
            #accept the loop variable across the job-context barrier
            param($path, $LogFile, $func)
            #----- define Days old to delete -----#
            $Days = "0"
            #----- define LastWriteTime parameter based on $Days -----#
            $LastWrite = (Get-Date).AddDays(-$Days)
            #execute command
            #----- count how many documents have been deleted -----#
            $Count = 0
            $hasError = $False
            #----- get files based on Lastwrite filter and specified folder -----#
            $Files = Get-ChildItem $path -file | Where-Object LastWriteTime -le "$LastWrite"
            if ($null -eq $Files) {
                
                if($Count -eq 0)
                {
                    [scriptblock]::Create($func).Invoke("No files were deleted within $path")
                }
                Exit
            }
            else {
                $Files | ForEach-Object {
                    try
                    {
                        $hasError = $False
                        #----- uncomment the line below to see the name of the files being deleted -----#
                        #Write-Host "Deleting File $_" - foregroundColor "DarkRed"
                        Remove-Item $_.FullName -Force -ErrorAction Stop | Out-Null
                        $Count++
                    }
                    catch
                    {
                        $hasError = $True
                        [scriptblock]::Create($func).Invoke($_.Exception.Message)
                    }
                }
                
                if(!$hasError)
                {
                    [scriptblock]::Create($func).Invoke("$Count files were deleted within $path")
                }
            }
        }
        
        #just wait for a bit...
        Start-Sleep 5
        
        #pass the loop variable acroos the job-context barrier
        Start-Job $scriptblock -ArgumentList $_, $LogFile, ${function:WriteLog} | Out-Null
    }
    else 
    {
        WriteLog "Error: $_ is not a valid folder path."
    }
}



#wait for all jobs to complete
while (Get-Job -State "Running") {
    Start-Sleep 2
}

#Display output from all Jobs
Get-Job | Wait-Job | Receive-Job

#cleanup
Remove-Job *
