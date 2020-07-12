# ==================================================================================================
# TERMINATION WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1

$BranchName = Get-WorkingBranchName

git -C $env:PPLibraryPath status --porcelain=v1 | ForEach-Object -Process {
    $CommitBool = 'n'

    if ($_ -match '^\?\? ') {
        $ChangeType = 'Added'
        $FilePath = Get-UntrackedFilePath -StatusString $_
        $CommitBool = Wait-ForUserResponse -UserActionRequired "Add '$FilePath'`?"
    }
    elseif ($_ -match '^ M ') {
        $ChangeType = 'Modified'
        $FilePath = Get-TrackedFilePath -StatusString $_
        Format-XmlFile -FilePath $FilePath
        $uuidRegen = Get-UUIDRegen $FilePath
        if ($uuidRegen -eq $false) {
            $CommitBool = Wait-ForUserResponse -UserActionRequired "Modify '$FilePath'`?"
        } else {
            # Do nothing
            $CommitBool = 'n'
        }
    }
    elseif ($_ -match '^ D ') {
        $ChangeType = 'Removed'
        $FilePath = Get-TrackedFilePath -StatusString $_
        $CommitBool = Wait-ForUserResponse -UserActionRequired "Remove '$FilePath'`?"
    }
    else {
        Write-HostWithPadding 'Unknown object - please contact support'
        $CommitBool = 'n'
    }


    if ($CommitBool -eq 'y') {

        if ($BranchName -eq 'master') {
            $BranchName = New-Branch
            Invoke-ChangeCommit -FilePath $FilePath -ChangeType $ChangeType
        }
        else {
            Invoke-ChangeCommit -FilePath $FilePath -ChangeType $ChangeType
        }
    }
    elseif ($CommitBool -eq 'n') {
        # Do nothing
    }
}

if ($BranchName -ne 'master') {
    Invoke-ChangePush -BranchName $BranchName
    New-PullRequest -BranchName $BranchName
} else {
    Write-HostWithPadding 'No changes added.'
}
