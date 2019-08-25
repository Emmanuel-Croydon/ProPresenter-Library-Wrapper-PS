# ==================================================================================================
# TERMINATION WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1

$BranchCreated = $false

git -C $env:PPLibraryPath status --porcelain | ForEach-Object -Process {
    if ($_ -match '^\?\?') {
        $ChangeType = 'Added'
        $FilePath = Get-UntrackedFilePath -StatusString $_
        $CommitBool = Wait-ForUserResponse -UserActionRequired "Add $FilePath`?"
    }
    elseif ($_ -match '^ M ') {
        $ChangeType = 'Modified'
        $FilePath = Get-TrackedFilePath -StatusString $_
        $CommitBool = Wait-ForUserResponse -UserActionRequired "Modify $FilePath`?"
    }
    elseif ($_ -match '^ D ') {
        $ChangeType = 'Removed'
        $FilePath = Get-TrackedFilePath -StatusString $_
        $CommitBool = Wait-ForUserResponse -UserActionRequired "Remove $FilePath`?"
    }
    else {
        Write-Host 'Unknown object - please contact support'
        $CommitBool = 'n'
    }

    if (($CommitBool -eq 'y') -and ($BranchCreated -eq $false)) {
        $BranchName = New-Branch
        Invoke-ChangeCommit -FilePath $FilePath -ChangeType $ChangeType
        $BranchCreated = $true
    }
    elseif (($CommitBool -eq 'y') -and ($BranchCreated -eq $true)) {
        Invoke-ChangeCommit -FilePath $FilePath -ChangeType $ChangeType
    }
    elseif ($CommitBool -eq 'n') {
        # Do nothing
    }
}

if ($BranchCreated -eq $true) {
    Invoke-ChangePush -BranchName $BranchName
    New-PullRequest -BranchName $BranchName
}
