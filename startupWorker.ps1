# ==================================================================================================
# STARTUP WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1


$response = Wait-ForUserResponse('Re-sync ProPresenter library with master database? (y/n)')

if ($response -eq 'y') {
    Sync-MasterLibrary
    $proc = Start-ProPresenter
} elseIf ($response -eq 'n') {
    $proc = Start-ProPresenter
}

return $proc
