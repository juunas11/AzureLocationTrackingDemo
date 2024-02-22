function Set-FrontendEnvFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string] $frontendDirectoryPath,

        [Parameter(Mandatory = $true)]
        [string] $adApplicationTenantId,

        [Parameter(Mandatory = $true)]
        [string] $adApplicationUri,

        [Parameter(Mandatory = $true)]
        [string] $azureAdClientId,

        [Parameter(Mandatory = $true)]
        [string] $mapsAccountClientId
    )

    Push-Location $frontendDirectoryPath

    Write-Host "Creating front-end environment files..."

    # The front-end supports a different env file for the production build,
    # but the values are the same for both environments in this demo app.
    $developmentEnvFilePath = ".env.development"
    $productionEnvFilePath = ".env.production"
    $frontendEnvFileContent = "VITE_AAD_TENANT_ID=$adApplicationTenantId`r`n"
    $frontendEnvFileContent += "VITE_AAD_CLIENT_ID=$azureAdClientId`r`n"
    $frontendEnvFileContent += "VITE_AAD_API_SCOPE=$adApplicationUri/user_impersonation`r`n"
    $frontendEnvFileContent += "VITE_MAPS_CLIENT_ID=$mapsAccountClientId"
    $frontendEnvFileContent | Out-File $developmentEnvFilePath -Encoding utf8 -NoNewline
    $frontendEnvFileContent | Out-File $productionEnvFilePath -Encoding utf8 -NoNewline

    Pop-Location
}

function Build-Frontend {
    param(
        [Parameter(Mandatory = $true)]
        [string] $frontendDirectoryPath
    )

    Push-Location $frontendDirectoryPath

    Write-Host "Building frontend..."
    npm install
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to install front-end dependencies."
    }
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        throw "Failed to build frontend."
    }

    Pop-Location
}