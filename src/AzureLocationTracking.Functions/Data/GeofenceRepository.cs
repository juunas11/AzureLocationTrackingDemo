using Microsoft.ApplicationInsights;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Spatial;

namespace AzureLocationTracking.Functions.Data;

public class GeofenceRepository
{
    private readonly CosmosClientWrapper _cosmosClientWrapper;
    private readonly TelemetryClient _telemetryClient;

    public GeofenceRepository(
        CosmosClientWrapper cosmosClientWrapper,
        TelemetryClient telemetryClient)
    {
        _cosmosClientWrapper = cosmosClientWrapper;
        _telemetryClient = telemetryClient;
    }

    public async Task<List<GeofenceDto>> GetGeofencesAsync()
    {
        var queryDef = new QueryDefinition("SELECT * FROM c");
        var iterator = _cosmosClientWrapper.GeofenceContainer.GetItemQueryIterator<GeofenceDto>(queryDef, requestOptions: new QueryRequestOptions
        {
            ConsistencyLevel = ConsistencyLevel.Session,
        });

        var results = new List<GeofenceDto>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(GetGeofencesAsync));

            results.AddRange(response);
        }

        return results;
    }

    public async Task<(Guid[] enteredGeofenceIds, BeforeUpdateGeofenceEventDto[] geofenceEventsToMarkAsExited)> GetEnteredAndExitedGeofenceIdsAsync(
        Guid vehicleId,
        Point location,
        DateTime eventTimestamp)
    {
        var beforeUpdateGeofencesTask = GetBeforeUpdateGeofenceEventsAsync(vehicleId, eventTimestamp);
        var collidingGeofencesTask = GetCollidingGeofencesAsync(location);

        await Task.WhenAll(beforeUpdateGeofencesTask, collidingGeofencesTask);

        var beforeUpdateGeofenceEvents = await beforeUpdateGeofencesTask;
        var beforeUpdateGeofences = beforeUpdateGeofenceEvents.Select(e => e.GeofenceId).ToList();
        var collidingGeofences = await collidingGeofencesTask;

        var enteredGeofenceIds = collidingGeofences.Except(beforeUpdateGeofences).ToArray();
        var geofenceEventsToMarkAsExited = beforeUpdateGeofenceEvents.Where(e => !collidingGeofences.Contains(e.GeofenceId)).ToArray();

        return (enteredGeofenceIds, geofenceEventsToMarkAsExited);
    }

    private async Task<List<BeforeUpdateGeofenceEventDto>> GetBeforeUpdateGeofenceEventsAsync(
        Guid vehicleId,
        DateTime eventTimestamp)
    {
        var queryDef = new QueryDefinition("""
            SELECT c.id, c.geofenceId
            FROM c
            WHERE c.vehicleId = @vehicleId AND c.entryTimestamp < @eventTimestamp AND (ISNULL(c.exitTimestamp) OR NOT IS_DEFINED(c.exitTimestamp))
            """)
            .WithParameter("@vehicleId", vehicleId)
            .WithParameter("@eventTimestamp", eventTimestamp);
        var iterator = _cosmosClientWrapper.VehiclesInGeofencesContainer.GetItemQueryIterator<BeforeUpdateGeofenceEventDto>(queryDef, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(vehicleId.ToString()),
            ConsistencyLevel = ConsistencyLevel.Session,
        });

        var results = new List<BeforeUpdateGeofenceEventDto>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(GetBeforeUpdateGeofenceEventsAsync));

            results.AddRange(response);
        }

        return results;
    }

    private async Task<List<Guid>> GetCollidingGeofencesAsync(Point location)
    {
        var queryDef = new QueryDefinition("""
            SELECT VALUE c.id
            FROM c
            WHERE ST_WITHIN(@location, c.border)
            """)
            .WithParameter("@location", location);

        var longitudeNumber = (int)Math.Floor(location.Position.Longitude);
        var latitudeNumber = (int)Math.Floor(location.Position.Latitude);
        var gridSquare = $"{longitudeNumber},{latitudeNumber}";

        var iterator = _cosmosClientWrapper.GeofenceContainer.GetItemQueryIterator<Guid>(queryDef, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(gridSquare),
            ConsistencyLevel = ConsistencyLevel.Session,
        });
        var results = new List<Guid>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(GetCollidingGeofencesAsync));

            results.AddRange(response);
        }

        return results;
    }

    public async Task AddVehicleInGeofencesAsync(
        Guid vehicleId,
        Guid[] enteredGeofenceIds,
        DateTime eventTimestamp)
    {
        foreach (var geofenceId in enteredGeofenceIds)
        {
            var response = await _cosmosClientWrapper.VehiclesInGeofencesContainer.CreateItemAsync(
                new
                {
                    id = Guid.NewGuid(),
                    vehicleId,
                    geofenceId,
                    entryTimestamp = eventTimestamp,
                },
                new PartitionKey(vehicleId.ToString()),
                new ItemRequestOptions
                {
                    EnableContentResponseOnWrite = false,
                });

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(AddVehicleInGeofencesAsync));
        }
    }

    public async Task SetVehicleOutOfGeofencesAsync(
        Guid vehicleId,
        BeforeUpdateGeofenceEventDto[] geofenceEventsToMarkAsExited,
        DateTime eventTimestamp)
    {
        foreach (var geofenceEvent in geofenceEventsToMarkAsExited)
        {
            var id = geofenceEvent.Id;
            var response = await _cosmosClientWrapper.VehiclesInGeofencesContainer.PatchItemAsync<GeofenceEventDto>(
                id,
                new PartitionKey(vehicleId.ToString()),
                new List<PatchOperation>
                {
                    PatchOperation.Set("/exitTimestamp", eventTimestamp),
                }, new PatchItemRequestOptions
                {
                    EnableContentResponseOnWrite = false,
                    ConsistencyLevel = ConsistencyLevel.Session,
                });

            var requestUnitsUsed = response.RequestCharge;
            _telemetryClient.GetMetric("Cosmos RU usage", "Method")
                .TrackValue(requestUnitsUsed, nameof(SetVehicleOutOfGeofencesAsync));
        }
    }
}
