$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot scriptModules\AzureActiveDirectory) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Frontend) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Initialization) -Force

$config = Get-Configuration -configPath (Join-Path $PSScriptRoot config.json)

Initialize-AzCli -config $config

$subscriptionId = $config.subscriptionId
$resourceGroup = $config.resourceGroup
$adApplicationUri = $config.adApplicationUri
$adApplicationTenantId = $config.adApplicationTenantId

Connect-MgGraph -TenantId $adApplicationTenantId -Scopes @("Application.ReadWrite.All") -ContextScope Process -NoWelcome

# Get Azure AD app client ID
$adApp = Get-AzureActiveDirectoryApplication -adApplicationUri $adApplicationUri
$adAppClientId = $adApp.appId

# Get Azure Maps account client ID
$mapsAccountClientId = az maps account list --subscription "$subscriptionId" -g "$resourceGroup" --query "[].properties.uniqueId" -o tsv
if ($LASTEXITCODE -ne 0) {
    throw "Failed to get Azure Maps account client ID."
}

Set-FrontendEnvFiles -frontendDirectoryPath (Join-Path $PSScriptRoot ..\src\AzureLocationTracking.Frontend -Resolve) -azureAdClientId $adAppClientId `
    -adApplicationTenantId $adApplicationTenantId -adApplicationUri $adApplicationUri `
    -mapsAccountClientId $mapsAccountClientId

Build-Frontend -frontendDirectoryPath ..\src\AzureLocationTracking.Frontend