﻿# ==================================================================================================
# LIBRARY FILE
# ==================================================================================================
#

function Start-ProPresenter { 
    Write-HostWithPadding 'Starting ProPresenter.....'
    $PropPresenterProc = Start-Process $env:ProPresenterEXE -PassThru
    return $PropPresenterProc
}

function Sync-MasterLibrary {
    Write-HostWithPadding 'Pulling down library from master node.....'
    git -C $env:PPLibraryPath reset --hard | Write-Debug
    git -C $env:PPLibraryPath clean -f -d | Write-Debug
    git -C $env:PPLibraryPath checkout master | Write-Debug
    
    $firstTry = $true    
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        $firstTry = $false
        $retry = 'n'
        git -C $env:PPLibraryPath pull | Write-Debug
        if(-not $?) {
            Write-Error -Message 'Failed to sync with master library. Please check your network connection and then retry.' -ErrorAction Continue
            $retry = Wait-ForUserResponse('Retry?')
        } else {
            Write-HostWithPadding 'Completed.'
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
        $response = Read-Host "    $UserActionRequired"
    
        if ($ValidResponses.Contains($response.toLower())) {
            return $response
        }
        else {
            Write-HostWithPadding "Invalid input. Please enter one of the following: $validResponsesOutput"
            Write-HostWithPadding '---------------------------------------------------------------------------'
        }
    }
    while(1 -eq 1)
}

function New-LockFile {
    $PID | Out-File -FilePath .\lock.pid
}

function Update-LockFile {
    $PID | Out-File -FilePath .\lock.pid -Force
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

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
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

    [Console.Window]::SetForegroundWindow($consolePtr)
    [Console.Window]::ShowWindow($consolePtr, 1)
    [Console.Window]::SetForegroundWindow($consolePtr)
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

    $Filepath = $StatusString | Select-String -Pattern "(?<=[""'])(.*)(?=[""'])" | foreach { $_.matches }

    if ($Filepath -eq $Null) {
        return $StatusString | Select-String -Pattern "(?<=\?\? )(.*)" | foreach { $_.matches }
    } else {
        return $Filepath
    }
}

function Get-TrackedFilePath {
    Param(
        [Parameter(Mandatory=$true)][string]$StatusString
    )

    $Filepath = $StatusString | Select-String -Pattern "(?<=[""'])(.*)(?=[""'])" | foreach { $_.matches }

    if ($Filepath -eq $Null) {
        return $StatusString | Select-String -Pattern "(?<= [MD] )(.*)" | foreach { $_.matches }
    } else {
        return $Filepath
    }
}

function New-Branch {
    $DateTime = Get-Date -Format "yyyy-MM-dd_HHmm"
    $User = "$env:COMPUTERNAME/$env:USERNAME"
    $BranchName = "AUTO/$User/$DateTime"
    git -C $env:PPLibraryPath checkout -b $BranchName | Write-Debug
    Invoke-BranchPush $BranchName
    return $BranchName
}

function Invoke-BranchPush {
    Param(
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    $firstTry = $true
    Write-HostWithPadding "Creating branch"
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        $firstTry = $false
        $retry = 'n'
        git -C $env:PPLibraryPath push --set-upstream origin $BranchName | Write-Debug

        if(-not $?) {
            Write-Error -Message "Failed to push branch. Please check your network connection and then retry.`r`n If network is currently unavailable, please do the following:`r`n`r`n1) Restart the app when a network connection is available. Do NOT sync with master library on start up.`r`n2) Quit ProPresenter to retry adding your changes to the master library.`r`n`r`n If this problem persists, please contact support." -ErrorAction Continue
            $retry = Wait-ForUserResponse('Retry?')
        } else {
            Write-HostWithPadding "Successfully pushed branch $BranchName"
        }
    }
}

function Invoke-ChangeCommit {
    Param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ChangeType
    )
    Write-Debug "Invoke commit"
    git -C $env:PPLibraryPath add $FilePath | Write-Debug
    $DateTime = Get-Date -Format "yyyy-MM-dd HH:mm"
    $User = "$env:COMPUTERNAME/$env:USERNAME"
    Write-Debug 'Change added'
    git -C $env:PPLibraryPath commit -m "$ChangeType $FilePath $DateTime $User" | Write-Debug
    Write-HostWithPadding 'Change committed'
}

function Invoke-ChangePush {
    Param(
        [Parameter(Mandatory=$true)][string]$BranchName
    )

    $firstTry = $true
    while (($firstTry -eq $true) -or ($retry -eq 'y')) {
        $firstTry = $false
        $retry = 'n'
        git -C $env:PPLibraryPath push | Write-Debug
            

        if(-not $?) {
            Write-Error -Message "Failed to push changes. Please check your network connection and then retry.`r`n If network is currently unavailable, please do the following:`r`n`r`n1) Restart the app when a network connection is available. Do NOT sync with master library on start up.`r`n2) Quit ProPresenter to retry adding your changes to the master library.`r`n`r`n If this problem persists, please contact support." -ErrorAction Continue
            $retry = Wait-ForUserResponse('Retry?')
        } else {
            Write-HostWithPadding "Pushed branch $BranchName"
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
        'Authorization' = "token $env:PPLibraryAuthToken"
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
        Invoke-RestMethod -Uri $GitHubRequestUri -Method $ReqMethod -ContentType 'application/json' -Headers $ReqHeaders -Body ($ReqBody | ConvertTo-Json) | Write-Debug
        Write-HostWithPadding "Successfully opened a pull request on $BranchName"
    }
    catch
    {
        Write-Error -Message "An error has occurred. Please give the support team the following information to add your changes: $BranchName" -ErrorAction Continue
        Start-Sleep(5)
        Remove-LockFile
        exit
    }
}

function Set-ConsoleFormat {
    $console = $host.UI.RawUI
    $console.WindowTitle = 'ProPresenter Library Wrapper'
    $console.ForegroundColor = 'Yellow'
}

function Get-WorkingBranchName {
    $BranchName = git -C $env:PPLibraryPath rev-parse --abbrev-ref HEAD
    Write-Debug "Working Branch: $BranchName"
    return $BranchName
}

function Write-SplashScreen {
    Write-Host -ForegroundColor DarkGreen -Object '





    ██████╗ ██████╗  ██████╗ ██████╗ ██████╗ ███████╗███████╗███████╗███╗   ██╗████████╗███████╗██████╗ 
    ██╔══██╗██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
    ██████╔╝██████╔╝██║   ██║██████╔╝██████╔╝█████╗  ███████╗█████╗  ██╔██╗ ██║   ██║   █████╗  ██████╔╝
    ██╔═══╝ ██╔══██╗██║   ██║██╔═══╝ ██╔══██╗██╔══╝  ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
    ██║     ██║  ██║╚██████╔╝██║     ██║  ██║███████╗███████║███████╗██║ ╚████║   ██║   ███████╗██║  ██║
    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
                                                                                                    
    ██╗     ██╗██████╗ ██████╗  █████╗ ██████╗ ██╗   ██╗                                                
    ██║     ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝                                                
    ██║     ██║██████╔╝██████╔╝███████║██████╔╝ ╚████╔╝                                                 
    ██║     ██║██╔══██╗██╔══██╗██╔══██║██╔══██╗  ╚██╔╝                                                  
    ███████╗██║██████╔╝██║  ██║██║  ██║██║  ██║   ██║                                                   
    ╚══════╝╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝                                                   
                                                                                                    
    ██╗    ██╗██████╗  █████╗ ██████╗ ██████╗ ███████╗██████╗                                           
    ██║    ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗                                          
    ██║ █╗ ██║██████╔╝███████║██████╔╝██████╔╝█████╗  ██████╔╝                                          
    ██║███╗██║██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗                                          
    ╚███╔███╔╝██║  ██║██║  ██║██║     ██║     ███████╗██║  ██║                                          
     ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝                                          
                                                              
                                                              
                                                              
                                                              
                                                              
                                                              '

    Start-Sleep(1)
}

function Write-HostWithPadding {
    Param(
        [Parameter(Mandatory=$true)][string]$String
    )

    Write-Host "    $String"
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
Export-ModuleMember -Function Invoke-BranchPush
Export-ModuleMember -Function New-PullRequest
Export-ModuleMember -Function Set-ConsoleFormat
Export-ModuleMember -Function Get-WorkingBranchName
Export-ModuleMember -Function Write-HostWithPadding
Export-ModuleMember -Function Write-SplashScreen
