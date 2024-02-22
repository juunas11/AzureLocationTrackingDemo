$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot scriptModules\AzureActiveDirectory) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\AzureDataExplorer) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\AzureResources) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\DeviceProvisioning) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Docker) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Frontend) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Functions) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Initialization) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\LocalSettings) -Force
Import-Module (Join-Path $PSScriptRoot scriptModules\Sql) -Force

# This script requires AZ CLI

# Run these before running script:
# Docker Desktop

## TODO:
## - Check IoT extension is installed: az extension list -o tsv --query "[].name"
##   should contain "azure-iot"
## - Install the extension if missing: az extension add --name azure-iot

$config = Get-Configuration -configPath (Join-Path $PSScriptRoot config.json)

Initialize-AzCli -config $config

$deploymentNamePrefix = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

Write-Host "Starting deployment..."

Set-ResourceGroup -config $config

Connect-MgGraph -TenantId $config.adApplicationTenantId -Scopes @("Application.ReadWrite.All") -ContextScope Process -NoWelcome
$adApp = Set-AzureActiveDirectoryApplication -config $config
$adApplicationScopeIdentifier = $adApp.adApplicationScopeIdentifier
$adAppClientId = $adApp.adAppClientId
$adAppObjectId = $adApp.adAppObjectId

$mainBicepOutputs = Deploy-MainTemplate -bicepDirectoryPath (Join-Path $PSScriptRoot bicep) -config $config `
    -deploymentNamePrefix $deploymentNamePrefix -adAppClientId $adAppClientId `
    -adApplicationScopeIdentifier $adApplicationScopeIdentifier

Set-ReplyUrls -adAppObjectId $adAppObjectId -mainBicepOutputs $mainBicepOutputs

$dpsKeys = Set-DpsEnrollmentGroups -config $config -mainBicepOutputs $mainBicepOutputs
$prodEnrollmentGroupPrimaryKey = $dpsKeys.prodEnrollmentGroupPrimaryKey
$devEnrollmentGroupPrimaryKey = $dpsKeys.devEnrollmentGroupPrimaryKey

Initialize-Sql -config $config -mainBicepOutputs $mainBicepOutputs `
    -dropAndCreateSchemaSqlPath (Join-Path $PSScriptRoot sql\dropAndCreateSchema.sql) `
    -seedSqlPath (Join-Path $PSScriptRoot sql\seed.sql)

Invoke-AdxSetupScript -mainBicepOutputs $mainBicepOutputs -setupScriptPath (Join-Path $PSScriptRoot adx\adx_setup.csl)

Deploy-AdxDataConnectionsTemplate -bicepDirectoryPath (Join-Path $PSScriptRoot bicep) `
    -config $config -mainBicepOutputs $mainBicepOutputs -deploymentNamePrefix $deploymentNamePrefix

Deploy-Container -mainBicepOutputs $mainBicepOutputs -sourceDirectoryPath (Join-Path $PSScriptRoot ..\src -Resolve)

$containerAppBicepOutputs = Deploy-ContainerAppTemplate -bicepDirectoryPath (Join-Path $PSScriptRoot bicep) -config $config `
    -mainBicepOutputs $mainBicepOutputs -deploymentNamePrefix $deploymentNamePrefix `
    -prodEnrollmentGroupPrimaryKey $prodEnrollmentGroupPrimaryKey

Deploy-DashboardTemplate -bicepDirectoryPath (Join-Path $PSScriptRoot bicep) -config $config -mainBicepOutputs $mainBicepOutputs `
    -deploymentNamePrefix $deploymentNamePrefix -containerAppBicepOutputs $containerAppBicepOutputs

Set-FrontendEnvFiles -frontendDirectoryPath (Join-Path $PSScriptRoot ..\src\AzureLocationTracking.Frontend -Resolve) -azureAdClientId $adAppClientId `
    -adApplicationTenantId $config.adApplicationTenantId -adApplicationUri $config.adApplicationUri `
    -mapsAccountClientId $mainBicepOutputs.mapsAccountClientId.value

Build-Frontend -frontendDirectoryPath (Join-Path $PSScriptRoot ..\src\AzureLocationTracking.Frontend -Resolve)

Deploy-FunctionApp -config $config -mainBicepOutputs $mainBicepOutputs `
    -functionAppDirectoryPath (Join-Path $PSScriptRoot ..\src\AzureLocationTracking.Functions -Resolve)

Write-Host "Deployment complete."

Write-Host "The Container App is set with scale 0-1 by default, so it will run for a moment and then stop."
Write-Host "To run it, go to the Azure Portal, find the Container App, and set the scale to e.g. 1-1."
$functionsAppHostName = $mainBicepOutputs.functionsAppHostName.value
Write-Host "Front-end URL: https://$functionsAppHostName"

Show-ContainerLocalSettings -mainBicepOutputs $mainBicepOutputs -devEnrollmentGroupPrimaryKey $devEnrollmentGroupPrimaryKey

Show-FunctionLocalSettings -config $config -mainBicepOutputs $mainBicepOutputs `
    -adAppClientId $adAppClientId -adApplicationScopeIdentifier $adApplicationScopeIdentifier