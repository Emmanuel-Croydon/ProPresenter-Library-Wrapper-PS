# ==================================================================================================
# STARTUP WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1

$firstTry = $true

while (($repeat -eq $true) -or ($firstTry -eq $true)) {
    $firstTry = $false
    $repeat = $false

    if ($env:PPLiveDevice -eq 1) {
        $response = Wait-ForUserResponse -UserActionRequired 'Re-sync ProPresenter library with master database? (y/n)' -ValidResponses @('y', 'n', 'r')
    } else {
        $response = 'y'
    }

    if ($response -eq 'y') {
        Sync-MasterLibrary | Out-Null
        $proc = Start-ProPresenter
    } elseIf ($response -eq 'n') {
        $proc = Start-ProPresenter
    } elseIf ($response -eq 'r') {
        $BranchName = git -C $env:PPLibraryPath rev-parse --abbrev-ref HEAD

        if ($BranchName -eq 'master') {
            Write-Host 'Could not find any changes to retry adding to master library'
        } else {
            Invoke-BranchPush $BranchName | Out-Null
        }
        $repeat = $true
    }
}

return $proc
