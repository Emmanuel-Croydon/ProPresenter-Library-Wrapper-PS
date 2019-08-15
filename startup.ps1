# SYSTEM VARIABLES
$ProPresenter = 'C:\Program Files (x86)\Renewed Vision\ProPresenter 6\ProPresenter.exe'
$LibraryPath = 'E:\Jon\Workspace\TestRepo\ProPresenter-Test-Library'
$RepoLocation = 'Jonathan-Mash/ProPresenter-Test-Library'

$response = Wait-ForUserResponse('Re-sync ProPresenter library with master database? (y/n)')

if ($response -eq 'y') {
    Sync-MasterLibrary
    $proc = Start-ProPresenter
} elseIf ($response -eq 'n') {
    $proc = Start-ProPresenter
}


function Start-ProPresenter { 
    Write-Host 'Starting ProPresenter.....'
    $proc = Start-Process $ProPresenter -PassThru
    return $proc
}

function Sync-MasterLibrary {
    Write-Host 'Pulling down library from master node.....'
    git -C $LibraryPath checkout master
    git -C $LibraryPath reset --hard
    git -C $LibraryPath pull
    Write-Host 'Completed.'
}

function Wait-ForUserResponse($UserActionRequired) {
    [array]$validResponses = 'y', 'n'
    [string]$validResponsesString = $null

    $validResponsesString = '"{0}"' -f ($validResponses -join '", "')

    do {
        $response = Read-Host $UserActionRequired
    
        if ($validResponses.Contains($response)) {
            return $response
        }
        else {
            Write-Host "Invalid input. Please enter one of the following: $validResponsesString"
            Write-Host '---------------------------------------------------------------------------'
        }
    }
    while(1 -eq 1)
}