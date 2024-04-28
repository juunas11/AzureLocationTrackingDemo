using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Messages;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Cosmos.Spatial;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace AzureLocationTracking.Functions;
public class UpdateLatestLocationEventFunction
{
    private readonly VehicleRepository _vehicleRepository;
    private readonly TelemetryClient _telemetryClient;

    public UpdateLatestLocationEventFunction(
        VehicleRepository vehicleRepository,
        TelemetryClient telemetryClient)
    {
        _vehicleRepository = vehicleRepository;
        _telemetryClient = telemetryClient;
    }

    [Function(nameof(UpdateLatestLocations))]
    [SignalROutput(HubName = "%AzureSignalRHubName%", ConnectionStringSetting = "AzureSignalRConnectionString")]
    public async Task<List<SignalRMessageAction>> UpdateLatestLocations(
        [EventHubTrigger("%EventHubName%", Connection = "EventHubConnection", ConsumerGroup = "latestLocationUpdate")] string[] events,
        FunctionContext functionContext)
    {
        _telemetryClient.GetMetric("Event Hub batch size", "Function")
            .TrackValue(events.Length, nameof(UpdateLatestLocations));

        var log = functionContext.GetLogger<CheckGeofencesEventFunction>();
        var exceptions = new List<Exception>();
        var signalRMessageActions = new List<SignalRMessageAction>();

        foreach (string eventData in events)
        {
            try
            {
                var ev = JsonSerializer.Deserialize<LocationUpdateEvent>(eventData);
                signalRMessageActions.AddRange(await ProcessLatestLocationUpdateAsync(ev));
                var totalProcessingTimeMs = (DateTime.UtcNow - ev.Ts).TotalMilliseconds;
                _telemetryClient
                    .GetMetric("Location update event processing time (ms)")
                    .TrackValue(totalProcessingTimeMs);
            }
            catch (Exception e)
            {
                log.LogError(e, "Failed to process message");
                // We need to keep processing the rest of the batch - capture this exception and continue.
                // Also, consider capturing details of the message that failed processing so it can be processed again later.
                exceptions.Add(e);
            }
        }

        // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.
        // Note the messages are not retried, the checkpoint is still created.
        if (exceptions.Count > 1)
        {
            throw new AggregateException(exceptions);
        }

        if (exceptions.Count == 1)
        {
            throw exceptions.Single();
        }

        return signalRMessageActions;
    }

    private async Task<List<SignalRMessageAction>> ProcessLatestLocationUpdateAsync(
        LocationUpdateEvent ev)
    {
        var vehicleId = ev.Id;
        var location = new Point(longitude: ev.Lng, latitude: ev.Lat);

        var signalRMessageActions = new List<SignalRMessageAction>();

        await _vehicleRepository.UpdateLatestLocationAsync(vehicleId, location);

        var gridLongitude = (int)Math.Floor(ev.Lng);
        var gridLatitude = (int)Math.Floor(ev.Lat);

        // Message is sent to a group of connections that are interested in the grid cell that the location is in.
        signalRMessageActions.Add(new SignalRMessageAction("locationUpdated", new object[]
        {
            vehicleId.ToString(),
            ev.Lat,
            ev.Lng,
            new DateTimeOffset(ev.Ts).ToUnixTimeMilliseconds(),
        })
        {
            GroupName = $"grid:{gridLongitude}:{gridLatitude}",
        });

        return signalRMessageActions;
    }
}
