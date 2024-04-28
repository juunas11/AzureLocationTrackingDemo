$ErrorActionPreference = "Stop"

$cosmosInitializerFolder = Join-Path $PSScriptRoot ..\src\AzureLocationTracking.CosmosInitializer -Resolve
Push-Location $cosmosInitializerFolder

dotnet run local https://localhost:8081 C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw== LocationDataDb Vehicles Geofences VehiclesInGeofences
if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize Cosmos DB"
}

Pop-Location
