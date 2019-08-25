# ==================================================================================================
# LIBRARY FILE
# ==================================================================================================
#

#TODO: Error handling doesn't work properly
#TODO: Check if change is only UUIDs
#TODO: Window focus for termination worker
#TODO: Can I do this without polling?
#TODO: Make prettier

function Start-ProPresenter { 
    Write-Host 'Starting ProPresenter.....'
    $PropPresenterProc = Start-Process $env:ProPresenterEXE -PassThru
    return $PropPresenterProc
}

function Sync-MasterLibrary {
    Write-Host 'Pulling down library from master node.....'
    git -C $env:PPLibraryPath reset --hard | Write-Host
    git -C $env:PPLibraryPath clean -f -d | Write-Host
    git -C $env:PPLibraryPath checkout master | Write-Host
    
    $firstTry = $true    
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        try
        {
            $firstTry = $false
            git -C $env:PPLibraryPath pull | Write-Host
            Write-Host 'Completed.'
        } catch {
            Write-Host "Failed to sync with master library. Please check your network connection and then retry.`r`n If network is currently unavailable, please enter 'r' for retry next time you start the app with a network connection.`r`n If the problem persists, please contact support."
            $retry = Wait-ForUserResponse('Retry?')
        }
    }
}

function Wait-ForUserResponse {
    Param(
        [Parameter(Mandatory=$true)][string]$UserActionRequired,
        [Parameter(Mandatory=$false)][string[]]$ValidResponses = @('y', 'n')
    )

    [string]$validResponsesString = $null
    $validResponsesString = '"{0}"' -f ($validResponses -join '", "')

    do {
        $response = Read-Host $UserActionRequired
    
        if ($ValidResponses.Contains($response.toLower())) {
            return $response
        }
        else {
            Write-Host "Invalid input. Please enter one of the following: $validResponsesString"
            Write-Host '---------------------------------------------------------------------------'
        }
    }
    while(1 -eq 1)
}

function New-LockFile {
    $text = "LOCKED BY: $PID"
    $text | Out-File -FilePath .\lock.pid
}

function Update-LockFile {
    $text = "LOCKED BY: $PID"
    $text | Out-File -FilePath .\lock.pid -Force
}

function Remove-LockFile {
    Remove-Item -Path .\lock.pid
}

# .Net methods for hiding/showing the console in the background
function Add-GetConsoleWindowFunction {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
}

function Show-Console
{
    $consolePtr = [Console.Window]::GetConsoleWindow()

    # Hide = 0,
    # ShowNormal = 1,
    # ShowMinimized = 2,
    # ShowMaximized = 3,
    # Maximize = 3,
    # ShowNormalNoActivate = 4,
    # Show = 5,
    # Minimize = 6,
    # ShowMinNoActivate = 7,
    # ShowNoActivate = 8,
    # Restore = 9,
    # ShowDefault = 10,
    # ForceMinimized = 11

    [Console.Window]::ShowWindow($consolePtr, 1)
}

function Hide-Console
{
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0)
}

function Get-UntrackedFilePath {
    Param(
        [Parameter(Mandatory=$true)][string]$StatusString
    )

    return $StatusString | Select-String -Pattern "(?<=\?\? )(.*)" | foreach { $_.matches }
}

function Get-TrackedFilePath {
    Param(
        [Parameter(Mandatory=$true)][string]$StatusString
    )

    return $StatusString | Select-String -Pattern "(?<=[""'])(.*)(?=[""'])" | foreach { $_.matches }
}

function New-Branch {
    $DateTime = Get-Date -Format "yyyy-MM-dd_HHmm"
    $User = "$env:COMPUTERNAME/$env:USERNAME"
    $BranchName = "AUTO/$User/$DateTime"
    git -C $env:PPLibraryPath checkout -b $BranchName | Write-Host
    Invoke-BranchPush $BranchName
    return $BranchName
}

function Invoke-BranchPush {
    Param(
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    $firstTry = $true
    Write-Host "Pushing branch"
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        try
        {
            $firstTry = $false
            git -C $env:PPLibraryPath push --set-upstream origin $BranchName | Write-Host
            Write-Host "Created branch $BranchName"
        } catch {
            Write-Host "Failed to push change. Please check your network connection and then retry.`r`n If network is currently unavailable, please enter 'r' for retry next time you start the app with a network connection.`r`n If the problem persists, please contact support."
            $retry = Wait-ForUserResponse('Retry?')
        }
    }
}

function Invoke-ChangeCommit {
    Param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ChangeType
    )
    Write-Host "Invoke commit"
    git -C $env:PPLibraryPath add $FilePath | Write-Host
    $DateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    $User = "$env:COMPUTERNAME/$env:USERNAME"
    Write-Host 'Change added'
    git -C $env:PPLibraryPath commit -m "$ChangeType $FilePath $DateTime $User" | Write-Host
    Write-Host 'Change committed'
}

function Invoke-ChangePush {
    Param(
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    $firstTry = $true
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        try
        {
            $firstTry = $false
            git -C $env:PPLibraryPath push | Write-Host
            Write-Host "Pushed branch $BranchName"
        } catch {
            Write-Host "Failed to push changes. Please check your network connection and then retry.`r`n If network is currently unavailable, please enter 'r' for retry next time you start the app with a network connection.`r`n If the problem persists, please contact support."
            $retry = Wait-ForUserResponse('Retry?')
        }
    }
}

function New-PullRequest {
    Param(
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    $DateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    
    # User whichever TLS site requires
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

    $GitHubRequestUri = "https://api.github.com/repos/$env:PPRepoLocation/pulls"
    $ReqMethod = 'Post'
    
    $ReqHeaders = 
    @{
        'Accept' = 'application/vnd.github.v3+json';
        'Authorization' = "token$env:PPLibraryAuthToken"
    }

    $ReqBody = 
    @{
      'title' = "AUTO pull request: $DateTime";
      'body' = "Pull Request created automatically by ProPresenter-Library-Wrapper at $DateTime";
      'head' = "$BranchName";
      'base' = 'master'
    }

    try 
    {
        Invoke-RestMethod -Uri $GitHubRequestUri -Method $ReqMethod -ContentType 'application/json' -Headers $ReqHeaders -Body ($ReqBody | ConvertTo-Json)
    }
    catch
    {
        Write-Host "An error has occurred. Please give the support team the following information to add your changes: $BranchName"
    }
}


Export-ModuleMember -Function Start-ProPresenter
Export-ModuleMember -Function Sync-MasterLibrary
Export-ModuleMember -Function Wait-ForUserResponse
Export-ModuleMember -Function Add-GetConsoleWindowFunction
Export-ModuleMember -Function New-LockFile
Export-ModuleMember -Function Update-LockFile
Export-ModuleMember -Function Remove-LockFile
Export-ModuleMember -Function Show-Console
Export-ModuleMember -Function Hide-Console
Export-ModuleMember -Function Get-UntrackedFilePath
Export-ModuleMember -Function Get-TrackedFilePath
Export-ModuleMember -Function New-Branch
Export-ModuleMember -Function Invoke-ChangeCommit
Export-ModuleMember -Function Invoke-ChangePush
Export-ModuleMember -Function New-PullRequest
