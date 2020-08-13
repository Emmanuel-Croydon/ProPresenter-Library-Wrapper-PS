# ==================================================================================================
# TERMINATION WORKER
# ==================================================================================================
#

Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module -Name .\library.psm1

$BranchName = Get-WorkingBranchName

dir $env:PPLibraryPath | ForEach-Object -Process {

    $directory = $_.Name
    $status = git -C $env:PPLibraryPath status "$directory" --porcelain=v1
    Write-Debug "STATUS: $status"

    if (($status.Count -gt 0) -and ($directory -ne 'Playlists') -and ((Wait-ForUserResponse -UserActionRequired "Make changes to '$directory'`?") -eq 'y')) {

        $status | ForEach-Object -Process {
            $CommitBool = 'n'

            if ($_ -match '^\?\? ') {
                $ChangeType = 'Added'
                $FilePath = Get-UntrackedFilePath -StatusString $_
                $CommitBool = Wait-ForUserResponse -UserActionRequired "Add '$FilePath'`?"
            }
            elseif ($_ -match '^ M ') {
                $ChangeType = 'Modified'
                $FilePath = Get-TrackedFilePath -StatusString $_
                $CommitBool = Wait-ForUserResponse -UserActionRequired "Modify '$FilePath'`?"
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
    }
}

if ($BranchName -ne 'master') {
    Invoke-ChangePush -BranchName $BranchName
    New-PullRequest -BranchName $BranchName
} else {
    Write-HostWithPadding 'No changes added.'
}
