# ==================================================================================================
# ORCHESTRATION WORKER
# ==================================================================================================
#

Param(
    [Alias('v')][switch]$verbose
)

# Verbose flag
if ($verbose -eq $true) {
    $global:DebugPreference = "Continue"
}

$ErrorActionPreference = 'Stop'

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1
Set-ConsoleFormat
Add-GetConsoleWindowFunction


# Basic process locking
if ((Test-Path -Path .\lock.pid) -eq $False) {
    New-LockFile
} else {
       $lockingpid = Get-Content -Path .\lock.pid
    if (!(Get-Process -pid $lockingpid -ErrorAction SilentlyContinue)) {
        Update-LockFile
    } else {
        Write-HostWithPadding "Process locked by $lockingpid"
        exit
    }
}

Write-SplashScreen

# Check environment variables installation
$envVars = @('ProPresenterEXE', 'PPLibraryPath', 'PPRepoLocation', 'PPLibraryAuthToken')
$envVars | forEach-Object {
    try {
        $Value = (get-item env:$_ -ErrorAction Stop).Value

        if ($Value -eq $null) {
            Throw 
        }
    } catch {
        Write-Error -Message 'An error has occurred with the installation of the ProPresenter Library Wrapper. Please contact support.' -ErrorAction Continue
        Remove-LockFile
        exit
    }
}

# Invoke startup worker
$ProPresenterProc = Invoke-Command -ScriptBlock {.\startupWorker.ps1}
Write-Debug $ProPresenterProc
Start-Sleep(5)

Hide-Console | Out-Null

# Monitor for process end
Register-ObjectEvent $ProPresenterProc -EventName Exited -SourceIdentifier 'ProPresenterTerminated' | Write-Debug

# Invoke termination worker
$terminationevent = Wait-Event -SourceIdentifier 'ProPresenterTerminated'

Show-Console | Out-Null
if ($verbose -ne $true) {
    Clear
}

$ProPresenterProc.WaitForExit()
$ExitCode = $ProPresenterProc.ExitCode
Write-Debug "Exit code: $ExitCode" 

if ($ExitCode -eq 0) {
    Invoke-Command -ScriptBlock {.\terminationWorker.ps1}
} else {
    Write-HostWithPadding 'Program terminated unexpectedly'
}

Start-Sleep(5)
Remove-LockFile
exit
