# ==================================================================================================
# ORCHESTRATION WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1


# Basic process locking
if ((Test-Path -Path .\lock.txt) -eq $False) {
    New-LockFile
} else {
       $lockingpid = (Get-Content -Path .\lock.txt).TrimStart('LOCKED BY: ')
    if (!(Get-Process -Id $lockingpid -ErrorAction SilentlyContinue)) {
        Update-LockFile
    } else {
        exit
    }
}

Add-GetConsoleWindowFunction

# Invoke startup worker
$ProPresenterProc = Invoke-Command -ScriptBlock {.\startupWorker.ps1}
Start-Sleep(5)
$terminated = $False


# Monitor for process end
Hide-Console
do {
    If ($ProPresenterProc.HasExited) {
        $ProPresenterProc.WaitForExit()
        $ExitCode = $ProPresenterProc.ExitCode
        $terminated = $True
    }
} while($terminated -eq $False)


# Invoke termination worker
Show-Console
Clear

if ($ExitCode -eq 0) {
    Invoke-Command -ScriptBlock {.\terminationWorker.ps1}
    Start-Sleep(5)
    Remove-LockFile
    exit
} else {
    Write-Host 'Program terminated unexpectedly'
    Start-Sleep(5)
    Remove-LockFile
    exit
}
