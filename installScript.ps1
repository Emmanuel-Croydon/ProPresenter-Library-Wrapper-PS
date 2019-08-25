# ==================================================================================================
# DEPLOYMENT SCRIPT
# ==================================================================================================
#

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
        Write-Host "Failed to add authentication. Please check your credentials and your network connection then retry."
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
        Write-Host "Failed to set environment variable $VariableName"
        Start-Sleep(5)
        exit
    }
    Write-Host "Successfully added $VariableName : $VariableValue"
}

Add-EnvironmentVariable -VariableName 'ProPresenterEXE' -VariableValue (Read-Host 'Please enter the location of the ProPresenter.exe')
Add-EnvironmentVariable -VariableName 'PPLibraryPath' -VariableValue (Read-Host 'Please enter the filepath for the ProPresenter library')
Add-EnvironmentVariable -VariableName 'PPRepoLocation' -VariableValue (Read-Host 'Please enter the location of the ProPresenter Library repository on GitHub (user/repo-name)')
Write-Host 'Please authenticate with Git repository...'
Add-EnvironmentVariable -VariableName 'PPLibraryAuthToken' -VariableValue (Get-AuthToken)
