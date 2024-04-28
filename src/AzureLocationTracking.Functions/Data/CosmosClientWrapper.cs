using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;

namespace AzureLocationTracking.Functions.Data;

public class CosmosClientWrapper
{
    public CosmosClientWrapper(IConfiguration configuration, CosmosClient cosmosClient)
    {
        var database = configuration["CosmosDatabase"];
        var vehicleContainer = configuration["CosmosVehicleContainer"];
        var vehiclesInGeofencesContainer = configuration["CosmosVehiclesInGeofencesContainer"];
        var geofenceContainer = configuration["CosmosGeofenceContainer"];
        VehicleContainer = cosmosClient.GetContainer(database, vehicleContainer);
        VehiclesInGeofencesContainer = cosmosClient.GetContainer(database, vehiclesInGeofencesContainer);
        GeofenceContainer = cosmosClient.GetContainer(database, geofenceContainer);
    }

    public Container VehicleContainer { get; }
    public Container VehiclesInGeofencesContainer { get; }
    public Container GeofenceContainer { get; }
}
