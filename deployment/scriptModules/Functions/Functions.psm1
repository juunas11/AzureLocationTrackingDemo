function Deploy-FunctionApp {
    param(
        [Parameter(Mandatory = $true)]
        [object] $config,

        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $functionAppDirectoryPath
    )

    $subscriptionId = $config.subscriptionId
    $resourceGroup = $config.resourceGroup

    Push-Location $functionAppDirectoryPath

    Write-Host "Creating Functions App deployment package..."
    dotnet publish --configuration Release --output publish_output
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Functions App deployment package."
    }

    Compress-Archive -Path .\publish_output\* -DestinationPath .\FunctionsPublish.zip -CompressionLevel Fastest -Force

    $functionsAppName = $mainBicepOutputs.functionsAppName.value

    Write-Host "Deploying Functions App..."
    az functionapp deployment source config-zip --subscription "$subscriptionId" -g "$resourceGroup" -n "$functionsAppName" --src .\FunctionsPublish.zip | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy Functions App."
    }

    Remove-Item -R .\publish_output
    Remove-Item .\FunctionsPublish.zip

    Pop-Location
}

Export-ModuleMember -Function Deploy-FunctionApp