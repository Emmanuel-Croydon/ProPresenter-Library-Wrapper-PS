# ==================================================================================================
# LIBRARY FILE
# ==================================================================================================
#


# SYSTEM VARIABLES
$ProPresenter = 'C:\Program Files (x86)\Renewed Vision\ProPresenter 6\ProPresenter.exe'
$LibraryPath = 'E:\Jon\Workspace\TestRepo\ProPresenter-Test-Library'
$RepoLocation = 'Jonathan-Mash/ProPresenter-Test-Library'



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

function New-LockFile {
    $text = "LOCKED BY: $PID"
    $text | Out-File -FilePath .\lock.txt
}

function Update-LockFile {
    $text = "LOCKED BY: $PID"
    $text | Out-File -FilePath .\lock.txt -Force
}

function Remove-LockFile {
    Remove-Item -Path .\lock.txt
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


Export-ModuleMember -Function Start-ProPresenter
Export-ModuleMember -Function Sync-MasterLibrary
Export-ModuleMember -Function Wait-ForUserResponse
Export-ModuleMember -Function Add-GetConsoleWindowFunction
Export-ModuleMember -Function New-LockFile
Export-ModuleMember -Function Update-LockFile
Export-ModuleMember -Function Remove-LockFile
Export-ModuleMember -Function Show-Console
Export-ModuleMember -Function Hide-Console
