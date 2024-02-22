Import-Module -Name Microsoft.Graph.Authentication
Import-Module -Name Microsoft.Graph.Applications

function Connect-Graph {
    param (
        [Parameter(Mandatory = $true)]
        [string] $tenantId
    )
    Connect-MgGraph -TenantId $tenantId -Scopes @("Application.ReadWrite.All") -ContextScope Process -NoWelcome
}

function Get-AzureActiveDirectoryApplication {
    param (
        [Parameter(Mandatory = $true)]
        [string] $adApplicationUri
    )
    
    return Get-MgApplication -Filter "identifierUris/any(x:x eq '$adApplicationUri')"
}

function Set-AzureActiveDirectoryApplication {
    param (
        [Parameter(Mandatory = $true)]
        [object] $config
    )

    $adApplicationUri = $config.adApplicationUri

    Write-Host "Creating/updating Azure AD app registration for Function App..."
    $adApp = Get-AzureActiveDirectoryApplication -adApplicationUri $adApplicationUri
    # $adApp = az ad app show --id $adApplicationUri | ConvertFrom-Json
    if ($null -eq $adApp) {
        # We can't set the reply URL yet as we don't know the Function App URL, we will set that after Bicep deployment
        $adAppApi = @{
            Oauth2PermissionScopes      = @(
                @{
                    Id                      = "acfcb4d1-12ae-4110-bcfa-d25ef875bf37"
                    IsEnabled               = $true
                    Type                    = "User"
                    Value                   = "user_impersonation"
                    UserConsentDisplayName  = "Call API as you"
                    UserConsentDescription  = "Allow the front-end to call the back-end on your behalf"
                    AdminConsentDisplayName = "Call API as the user"
                    AdminConsentDescription = "Allow the front-end to call the back-end on the signed in user's behalf"
                }
            )
            RequestedAccessTokenVersion = 2
        }

        $adApp = New-MgApplication -DisplayName "Azure Location Tracking Demo" -IdentifierUris @($adApplicationUri) -SignInAudience "AzureADMyOrg" -Api $adAppApi
        Write-Host "Created new Azure AD app registration for Function App"
        New-MgServicePrincipal -AppId $adApp.AppId | Out-Null
        Write-Host "Created Azure AD service principal for the app registration"
    }
    else {
        Write-Host "Found existing Azure AD app registration for Function App with client ID $($adApp.appId)"
    }

    return @{   
        adApplicationScopeIdentifier = "$adApplicationUri/user_impersonation"
        adAppClientId                = $adApp.appId
        adAppObjectId                = $adApp.id
    }
}

function Set-ReplyUrls {
    param(
        [Parameter(Mandatory = $true)]
        [string] $adAppObjectId,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs
    )

    # Update the Azure AD app with correct reply URL
    $functionsAppHostName = $mainBicepOutputs.functionsAppHostName.value
    $functionsAppReplyUrl = "https://$functionsAppHostName"
    $adAppSpa = @{
        RedirectUris = @(
            'http://localhost:7090'
            'http://localhost:5173'
            $functionsAppReplyUrl
        )
    }
    Update-MgApplication -ApplicationId $adAppObjectId -Spa $adAppSpa | Out-Null
    Write-Host "Updated Azure AD app registration with reply URLs"
}

Export-ModuleMember -Function Connect-Graph, Get-AzureActiveDirectoryApplication, Set-AzureActiveDirectoryApplication, Set-ReplyUrls