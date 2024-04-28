using Microsoft.ApplicationInsights;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Spatial;

namespace AzureLocationTracking.Functions.Data;

public class VehicleRepository
{
    private readonly CosmosClientWrapper _cosmosClientWrapper;
    private readonly TelemetryClient _telemetryClient;

    public VehicleRepository(
        CosmosClientWrapper cosmosClientWrapper,
        TelemetryClient telemetryClient)
    {
        _cosmosClientWrapper = cosmosClientWrapper;
        _telemetryClient = telemetryClient;
    }

    public async Task UpdateLatestLocationAsync(
        Guid vehicleId,
        Point location)
    {
        var response = await _cosmosClientWrapper.VehicleContainer.PatchItemAsync<VehicleDto>(
            vehicleId.ToString(),
            new PartitionKey(vehicleId.ToString()),
            new List<PatchOperation>
            {
                PatchOperation.Set("/latestLocation", location)
            },
            new PatchItemRequestOptions
            {
                EnableContentResponseOnWrite = false,
            });

        var requestUnitsUsed = response.RequestCharge;
        _telemetryClient.GetMetric("Cosmos RU usage", "Method")
        .TrackValue(requestUnitsUsed, nameof(UpdateLatestLocationAsync));
    }

    public async Task<IEnumerable<LatestGeofenceEventDto>> GetLatestGeofenceEvents(Guid vehicleId)
    {
        var queryDef = new QueryDefinition("""
            SELECT TOP 5 c.geofenceId, c.entryTimestamp, c.exitTimestamp
            FROM c
            WHERE c.vehicleId = @vehicleId
            ORDER BY c.entryTimestamp DESC
            """)
            .WithParameter("@vehicleId", vehicleId);
        var iterator = _cosmosClientWrapper.VehiclesInGeofencesContainer.GetItemQueryIterator<LatestGeofenceEventDto>(queryDef, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(vehicleId.ToString()),
            ConsistencyLevel = ConsistencyLevel.Session,
        });

        var results = new List<LatestGeofenceEventDto>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(GetLatestGeofenceEvents));

            results.AddRange(response);
        }

        return results;
    }
}
