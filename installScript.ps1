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
    
    $GitHubOauthDeviceFlowUri = 'https://github.com/login/device/code?client_id=9603bcd797e8961affd5&scope=repo'
    $response = Invoke-RestMethod -Uri $GitHubOauthDeviceFlowUri -Method 'Post' -ErrorAction Stop
    
    $responseHash = @{}
    Foreach ($param in $response.Split('&')) {
        $responseHash += ConvertFrom-StringData $param
    }

    $verificationUri = [System.Web.HttpUtility]::UrlDecode($responseHash.verification_uri)
    $userCode = $responseHash.user_code
    $deviceCode = $responseHash.device_code

    Write-Host "Please navigate to this URL $verificationUri and enter the following code: $userCode"

    $timer =  [system.diagnostics.stopwatch]::StartNew()
    $expiryTime = $responseHash.expires_in -as [int]
    $pollInterval = $responseHash.interval -as [int]
    $authorized = $false

    $GitHubOauthPollAuthorizationUri = "https://github.com/login/oauth/access_token?client_id=9603bcd797e8961affd5&device_code=$deviceCode&grant_type=urn:ietf:params:oauth:grant-type:device_code"
    
    While(($timer.Elapsed.TotalSeconds -lt $expiryTime) -and ($authorized -eq $false)) {
        $authResponse = Invoke-RestMethod -Uri $GitHubOauthPollAuthorizationUri -Method 'Post' -ErrorAction Stop

        $authResponseHash = @{}
        Foreach ($param in $authResponse.Split('&')) {
            $authResponseHash += ConvertFrom-StringData $param
        }

        $authorized = $authResponseHash.ContainsKey('access_token')

        Start-Sleep $pollInterval
    }

    if ($authorized) {
        return $authResponseHash.access_token
    } else {
        Write-Error "Authorization has failed before expiry, please try again."
        exit
    }
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

function Copy-IconToDefaultLocation {
    $wd = Get-Location
    $path = "$env:SystemRoot\System32"
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
    $UserDesktopShortcut = "$UserDesktopPath\ProPresenter.lnk"
    $SharedDesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $SharedDesktopShortcut = "$SharedDesktopPath\ProPresenter.lnk"

    if ((Test-Path -Path $UserDesktopShortcut) -eq $True) {
        Remove-Item $UserDesktopShortcut
    } else {
        Write-Warning -Message 'Could not find shortcut on desktop' -ErrorAction Continue
    }

    Copy-TemplateShortcutToLocation $UserDesktopPath
    Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to User Desktop'

    if ((Test-Path -Path $SharedDesktopShortcut) -eq $True) {
        Remove-Item $SharedDesktopShortcut
    } else {
        Write-Warning -Message 'Could not find shortcut on shared desktop' -ErrorAction Continue
    }

    Copy-TemplateShortcutToLocation $SharedDesktopPath
    Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to Shared Desktop'
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
# Bastardise-OriginalPropresenterShortcut $config['PPShortcutLocation']
Write-Host 'Successfully copied ProPresenter Library Wrapper shortcut to Start Menu'

Replace-CommonProPresenterShortcuts

Write-Host 'Please authenticate with Git repository...'
Add-EnvironmentVariable -VariableName 'PPLibraryAuthToken' -VariableValue (Get-AuthToken)

$repoPath = $config['PPRepoLocation']
$libraryDir = $config['PPLibraryPath']

if ((Test-Path -Path $libraryDir) -eq $True) {
    
    if ((Test-Path -Path "$libraryDir\\.git") -eq $True) {
        Remove-Item "$libraryDir\\.git" -Recurse -Force
    }

    git -C $libraryDir init
    git -C $libraryDir remote add origin "https://github.com/$repoPath.git"
    git -C $libraryDir fetch
    git -C $libraryDir checkout -t origin/master -f
} else {
    Write-Error -Message 'Could not find library directory' -ErrorAction Continue
}
Unblock-File .\orchestrationWorker.ps1
Unblock-File .\startupWorker.ps1
Unblock-File .\terminationWorker.ps1
Unblock-File .\library.psm1


Start-Sleep(5)