# ==================================================================================================
# DEPLOYMENT SCRIPT
# ==================================================================================================
#

#Requires -RunAsAdministrator

Set-ExecutionPolicy RemoteSigned -Scope Process

$ErrorActionPreference = 'Stop'

function Get-AuthToken {

    # Use whichever TLS site requires
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    
    $GitHubAuthUri = 'https://api.github.com/authorizations'
    $User = "$env:COMPUTERNAME/$env:USERNAME"
    
    $Base64String = "$(Read-Host 'Username'):$(Read-Host -AsSecureString 'Password' | 
                     foreach {[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))})" | 
                     foreach { [System.Convert]::ToBase64String([char[]]$_) }

    $AuthHeaders = 
    @{
        'Accept' = 'application/vnd.github.v3+json';
        'Authorization' = "Basic $Base64String"
    }

    $AuthBody = 
    @{
        'scopes' = @("repo");
        'note' = "$User ProPresenter-Library-Wrapper"
    }

    try {
        $Token = Invoke-RestMethod -Uri $GitHubAuthUri -Method 'Post'-ContentType 'application/json' -Headers $AuthHeaders -Body ($AuthBody | ConvertTo-Json) -ErrorAction Stop
        Write-Host "Successfully added Github API authentication."
    } catch {
        Write-Error -Message 'Failed to add authentication. Please check your credentials and your network connection then retry.' -ErrorAction Continue
        Start-Sleep(5)
        exit
    }

    return $Token.token
}


function Add-EnvironmentVariable {
    Param(
        [Parameter(Mandatory=$true)][string]$VariableName,
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)][string]$VariableValue
    )

    try {
        [Environment]::SetEnvironmentVariable($VariableName, $VariableValue, 'User')
    } catch {
        Write-Error "Failed to set environment variable $VariableName"
        Start-Sleep(5)
        exit
    }
    Write-Host "Successfully added $VariableName : $VariableValue"
}


function Read-EnvProperties {
    Param(
        [Parameter(Mandatory=$true)][string]$Filename
    )
    $filecontent = Get-Content $Filename -raw
    $filecontent = $filecontent -join [Environment]::NewLine
    $config = ConvertFrom-StringData($filecontent)
    return $config
}


function Edit-TemplateShortcut {
    Param(
        [Parameter(Mandatory=$true)][string]$IconLocation
    )

    $wd = Get-Location
    $path = "$wd\ProPresenter Library Wrapper.lnk"
    $targetpath = "$wd\orchestrationWorker.ps1"
    $obj = New-Object -ComObject WScript.Shell
    $link = $obj.CreateShortcut($path)
    
    $link.Arguments = "-File $targetpath"
    $link.WorkingDirectory = "$wd"
    $link.IconLocation = "$IconLocation,0"

    $link.Save()
    Write-Host 'Successfully edited template shortcut'
}


function Copy-TemplateShortcutToLocation {
    Param(
        [Parameter(Mandatory=$true)][string]$DestinationLocation
    )

    $wd = Get-Location
    $path = "$wd\ProPresenter Library Wrapper.lnk"
    if ((Test-Path -Path $DestinationLocation) -eq $True) {
        Copy-Item -Path $path -Destination $DestinationLocation
    } else {
        Write-Error -Message 'Could not find template shortcut' -ErrorAction Continue
    }
}

function Copy-IconToLocation {
    $wd = Get-Location
    $path = "%SystemRoot%\System32"
    $icon = "$wd\Pro7_wrapper.ico"

    if ((Test-Path -Path $path) -eq $True) {
        Copy-Item -Path $icon -Destination $path
    } else {
        Write-Error -Message 'Could not find icon location' -ErrorAction Continue
    }
}


function Bastardise-OriginalPropresenterShortcut {
    Param(
        [Parameter(Mandatory=$true)][string]$ShortcutLocation
    )

	$OriginalPropresenterShortcut = "$ShortcutLocation\ProPresenter 6.lnk";
	
	if ((Test-Path -Path $OriginalPropresenterShortcut) -eq $True) {
		Rename-Item -Path $OriginalPropresenterShortcut -NewName "___PP6exe_DONOTUSE___.lnk"
	} elseif ((Test-Path -Path "$ShortcutLocation\___PP6exe_DONOTUSE___.lnk") -eq $True) {
        Write-Host 'Original ProPresenter shortcut already renamed'
    } else {
        Write-Error -Message 'Could not find original ProPresenter shortcut' -ErrorAction Continue
    }
}


function Replace-CommonProPresenterShortcuts {
    
    $UserDesktopPath = [Environment]::GetFolderPath("Desktop")
    $UserDesktopShortcut = "$UserDesktopPath\ProPresenter 6.lnk"
    $SharedDesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $SharedDesktopShortcut = "$SharedDesktopPath\ProPresenter 6.lnk"

    if ((Test-Path -Path $UserDesktopShortcut) -eq $True) {
        Remove-Item $UserDesktopShortcut
        Copy-TemplateShortcutToLocation $UserDesktopPath
        Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to User Desktop'
    } else {
        Write-Error -Message 'Could not find shortcut on desktop' -ErrorAction Continue
    }

    if ((Test-Path -Path $SharedDesktopShortcut) -eq $True) {
        Remove-Item $SharedDesktopShortcut
        Copy-TemplateShortcutToLocation $SharedDesktopPath
        Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to Shared Desktop'
    } else {
        Write-Error -Message 'Could not find shortcut on shared desktop' -ErrorAction Continue
    }
}


$config = Read-EnvProperties -Filename ".\envConfig.properties"

Foreach($Key in $config.Keys) {
    $Value = $config[$Key]
    if ($Key -ne 'PPShortcutLocation') {
        Add-EnvironmentVariable -VariableName $key -VariableValue $value
    }
}

Add-EnvironmentVariable -VariableName 'GIT_REDIRECT_STDERR' -VariableValue '2>&1'

Edit-TemplateShortcut $config['ProPresenterEXE']
Copy-TemplateShortcutToLocation $config['PPShortcutLocation']
Copy-IconToDefaultLocation
Bastardise-OriginalPropresenterShortcut $config['PPShortcutLocation']
Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to Start Menu'

Replace-CommonProPresenterShortcuts

Write-Host 'Please authenticate with Git repository...'
Add-EnvironmentVariable -VariableName 'PPLibraryAuthToken' -VariableValue (Get-AuthToken)

$repoPath = $config['PPRepoLocation']
$libraryDir = $config['PPLibraryPath']

if ((Test-Path -Path $libraryDir) -eq $True) {
    git -C $libraryDir init
    git -C $libraryDir remote add origin "https://github.com/$repoPath.git"
    git -C $libraryDir fetch
    git -C $libraryDir checkout -t origin/master -f
} else {
    Write-Error -Message 'Could not find library directory' -ErrorAction Continue
}

Start-Sleep(5)