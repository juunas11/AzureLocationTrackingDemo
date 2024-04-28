function Deploy-Container {
    param(
        [Parameter(Mandatory = $true)]
        [object] $mainBicepOutputs,

        [Parameter(Mandatory = $true)]
        [string] $sourceDirectoryPath
    )

    Push-Location $sourceDirectoryPath

    $containerRegistryName = $mainBicepOutputs.containerRegistryName.value
    $tag = "$containerRegistryName.azurecr.io/simulatedvehicle"

    Write-Host "Building container..."
    docker build -f .\AzureLocationTracking.VehicleSimulator\Dockerfile --tag "$tag" .
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build container."
    }

    az acr login --name $containerRegistryName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to login to container registry."
    }

    Write-Host "Pushing container..."
    docker push "$tag"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push container."
    }

    Pop-Location
}

Export-ModuleMember -Function Deploy-Container