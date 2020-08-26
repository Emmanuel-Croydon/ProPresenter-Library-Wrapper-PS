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

    $changeTypes = @('Added', 'Modified', 'Removed', 'Unknown')

    foreach ($ChangeType in $changeTypes) {
        if ($ChangeType -eq 'Added') {
            $matcher = '^\?\? '
            $DirLevelMessage = "Add items to '$directory'`?"
            $FileLevelMessage = "    - Add '{FilePath}'`?"
        }
        elseif ($ChangeType -eq 'Modified') {
            $matcher = '^ M '
            $DirLevelMessage = "Modify items in '$directory'`?"
            $FileLevelMessage = "    - Modify '{FilePath}'`?"
        }
        elseif ($ChangeType -eq 'Removed') {
            $matcher = '^ D '
            $DirLevelMessage = "Remove items from '$directory'`?"
            $FileLevelMessage = "    - Remove '{FilePath}'`?"
        }
        elseif ($ChangeType -eq 'Unknown') {
            $matcher = '^(?!\?\? .*$)(?! D .*$)(?! M .*$).*'
        }

        $statusFilter = $status | Where-Object {$_ -match "$matcher"}
        Write-Debug "ChangeType: $ChangeType"
        Write-Debug "statusFilter: $statusFilter"

        if (($ChangeType -eq 'Unknown') -and ($statusFilter.Count -gt 0)) {
            Write-HostWithPadding 'Unknown change object detected - please contact support'
        }

        if (($ChangeType -ne 'Unknown') -and ($statusFilter.Count -gt 0) -and ($directory -ne 'Playlists') -and ((Wait-ForUserResponse -UserActionRequired "$DirLevelMessage") -eq 'y')) {
            
            Write-HostWithPadding "`n"

            $statusFilter | ForEach-Object -Process {
                $CommitBool = 'n'

                if (($_ -match "$matcher") -and ($ChangeType -eq 'Added')) {
                    $FilePath = Get-UntrackedFilePath -StatusString $_
                    $CommitBool = Wait-ForUserResponse -UserActionRequired $("$FileLevelMessage" -replace '{FilePath}', "$FilePath")
                }
                elseif ($_ -match "$matcher") {
                    $FilePath = Get-TrackedFilePath -StatusString $_
                    $CommitBool = Wait-ForUserResponse -UserActionRequired $("$FileLevelMessage" -replace '{FilePath}', "$FilePath")
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

            Write-HostWithPadding "`n"
        }
    }
}

if ($BranchName -ne 'master') {
    Invoke-ChangePush -BranchName $BranchName
    New-PullRequest -BranchName $BranchName
} else {
    Write-HostWithPadding 'No changes added.'
}
