# ==================================================================================================
# ORCHESTRATION WORKER
# ==================================================================================================
#

Param(
    [Alias('v')][switch]$verbose
)

$ErrorActionPreference = 'Stop'

# Verbose flag
if ($verbose -eq $true) {
    $DebugPreference = "Continue"
}

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

# Check environment variables installation
$envVars = @('ProPresenterEXE', 'PPLibraryPath', 'PPRepoLocation', 'PPLibraryAuthToken')
$envVars | forEach-Object {
    try {
        $Value = (get-item env:$_ -ErrorAction Stop).Value

        if ($Value -eq $null) {
            Throw 
        }
    } catch {
        Write-Error 'An error has occurred with the installation of the ProPresenter Library Wrapper. Please contact support.'
        Remove-LockFile
        exit
    }
}

# Invoke startup worker
$ProPresenterProc = Invoke-Command -ScriptBlock {.\startupWorker.ps1}
Write-Debug $ProPresenterProc
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
    Start-Sleep(2)
} while($terminated -eq $False)


# Invoke termination worker
Show-Console
Clear

if ($ExitCode -eq 0) {
    Invoke-Command -ScriptBlock {.\terminationWorker.ps1}
    Remove-LockFile
    exit
} else {
    Write-Host 'Program terminated unexpectedly'
    Start-Sleep(3)
    Remove-LockFile
    exit
}
