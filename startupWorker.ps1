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
        $response = Wait-ForUserResponse -UserActionRequired "Re-sync ProPresenter library with master database? (y/n)`r`n    (This will overwrite your local changes)" -ValidResponses @('y', 'n')
    } else {
        $response = 'y'
    }

    if ($response -eq 'y') {
        Sync-MasterLibrary | Out-Null
        Remove-LeftoverPlaylistData
        Copy-LabelTemplateFile
        $proc = Start-ProPresenter
    } elseIf ($response -eq 'n') {
        $proc = Start-ProPresenter
    }
}

return $proc
