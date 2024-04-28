Import-Module SqlServer

function Get-SqlAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string] $tenantId
    )

    $sqlAccessTokenResult = az account get-access-token --tenant "$tenantId" --resource "https://database.windows.net" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get SQL access token."
    }

    return $sqlAccessTokenResult.accessToken
}

function Set-ContainerAppUser {
    param(
        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $sqlAccessToken,

        [Parameter(Mandatory = $true)]
        [string] $sqlServerFqdn,

        [Parameter(Mandatory = $true)]
        [string] $sqlDbName
    )

    $containerAppIdentityName = $mainBicepOutputs.containerAppIdentityName.value
    $createContainerAppUser = "IF NOT EXISTS (SELECT [name] `
FROM [sys].[database_principals] `
WHERE [type] = N'E' AND [name] = N'$containerAppIdentityName') `
CREATE USER [$containerAppIdentityName] FROM EXTERNAL PROVIDER;"
    $grantContainerAppSqlAccess = "GRANT SELECT, INSERT, DELETE ON [dbo].[Vehicles] TO [$containerAppIdentityName];"

    Write-Host "Creating Container App SQL user..."
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -Query $createContainerAppUser
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -Query $grantContainerAppSqlAccess
}

function Set-FunctionAppUser {
    param(
        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $sqlAccessToken,

        [Parameter(Mandatory = $true)]
        [string] $sqlServerFqdn,

        [Parameter(Mandatory = $true)]
        [string] $sqlDbName
    )

    $functionsAppIdentityName = $mainBicepOutputs.functionsAppIdentityName.value
    $createFunctionsAppUser = "IF NOT EXISTS (SELECT [name] `
FROM [sys].[database_principals] `
WHERE [type] = N'E' AND [name] = N'$functionsAppIdentityName') `
CREATE USER [$functionsAppIdentityName] FROM EXTERNAL PROVIDER;"
    $grantFunctionsAppSqlAccess = "GRANT SELECT, UPDATE ON [dbo].[Vehicles] TO [$functionsAppIdentityName];"
    $grantFunctionsAppSqlAccess += "GRANT SELECT ON [dbo].[Geofences] TO [$functionsAppIdentityName];"
    $grantFunctionsAppSqlAccess += "GRANT SELECT, INSERT, UPDATE, DELETE ON [dbo].[VehiclesInGeofences] TO [$functionsAppIdentityName];"

    Write-Host "Creating Functions App SQL user..."
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -Query $createFunctionsAppUser
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -Query $grantFunctionsAppSqlAccess
}

function Initialize-Sql {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $updateSchemaSqlPath,

        [Parameter(Mandatory = $true)]
        [string] $seedSqlPath
    )

    Write-Host "Running SQL deployments..."

    $sqlAccessToken = Get-SqlAccessToken -tenantId $config.tenantId

    $sqlServerFqdn = $mainBicepOutputs.sqlServerFqdn.value
    $sqlDbName = $mainBicepOutputs.sqlDbName.value

    Write-Host "Creating/updating SQL schema..."
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -InputFile $updateSchemaSqlPath
    Write-Host "Inserting seed data to SQL..."
    Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDbName -AccessToken $sqlAccessToken -InputFile $seedSqlPath

    Set-ContainerAppUser -mainBicepOutputs $mainBicepOutputs -sqlAccessToken $sqlAccessToken `
        -sqlServerFqdn $sqlServerFqdn -sqlDbName $sqlDbName

    Set-FunctionAppUser -mainBicepOutputs $mainBicepOutputs -sqlAccessToken $sqlAccessToken `
        -sqlServerFqdn $sqlServerFqdn -sqlDbName $sqlDbName
}

Export-ModuleMember -Function Initialize-Sql