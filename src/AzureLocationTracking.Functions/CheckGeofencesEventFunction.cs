using System.Text.Json;
using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Messages;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Cosmos.Spatial;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace AzureLocationTracking.Functions;

public class CheckGeofencesEventFunction
{
    private readonly GeofenceRepository _geofenceRepository;
    private readonly TelemetryClient _telemetryClient;

    public CheckGeofencesEventFunction(
        GeofenceRepository geofenceRepository,
        TelemetryClient telemetryClient)
    {
        _geofenceRepository = geofenceRepository;
        _telemetryClient = telemetryClient;
    }

    [Function(nameof(CheckGeofences))]
    [SignalROutput(HubName = "%AzureSignalRHubName%", ConnectionStringSetting = "AzureSignalRConnectionString")]
    public async Task<List<SignalRMessageAction>> CheckGeofences(
        [EventHubTrigger("%EventHubName%", Connection = "EventHubConnection", ConsumerGroup = "geofenceCheck")] string[] events,
        FunctionContext functionContext)
    {
        _telemetryClient.GetMetric("Event Hub batch size", "Function")
            .TrackValue(events.Length, nameof(CheckGeofences));

        var log = functionContext.GetLogger<CheckGeofencesEventFunction>();
        var exceptions = new List<Exception>();
        var signalRMessageActions = new List<SignalRMessageAction>();

        foreach (string eventData in events)
        {
            try
            {
                var ev = JsonSerializer.Deserialize<LocationUpdateEvent>(eventData);
                signalRMessageActions.AddRange(await ProcessGeofenceCheckAsync(ev));
                var totalProcessingTimeMs = (DateTime.UtcNow - ev.Ts).TotalMilliseconds;
                _telemetryClient
                    .GetMetric("Geofence check event processing time (ms)")
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

    private async Task<List<SignalRMessageAction>> ProcessGeofenceCheckAsync(
        LocationUpdateEvent ev)
    {
        var vehicleId = ev.Id;
        var location = new Point(longitude: ev.Lng, latitude: ev.Lat);

        var signalRMessageActions = new List<SignalRMessageAction>();

        var geofenceEvents = await CheckGeofencesAsync(vehicleId, location, ev.Ts);
        var longitudeNumber = (int)Math.Floor(ev.Lng);
        var latitudeNumber = (int)Math.Floor(ev.Lat);

        foreach (var geofenceEvent in geofenceEvents)
        {
            signalRMessageActions.Add(new SignalRMessageAction(
                geofenceEvent.Type == GeofenceEventType.Entry ? "geofenceEntered" : "geofenceExited",
                new object[]
                {
                    vehicleId.ToString(),
                    geofenceEvent.GeofenceId,
                }
            ){
                GroupName = $"grid:{longitudeNumber}:{latitudeNumber}",
            });
        }

        return signalRMessageActions;
    }

    private async Task<List<GeofenceEvent>> CheckGeofencesAsync(
        Guid vehicleId,
        Point location,
        DateTime eventTimestamp)
    {
        var (enteredGeofenceIds, geofenceEventsToMarkAsExited) = await _geofenceRepository
            .GetEnteredAndExitedGeofenceIdsAsync(vehicleId, location, eventTimestamp);

        await _geofenceRepository.AddVehicleInGeofencesAsync(vehicleId, enteredGeofenceIds, eventTimestamp);

        await _geofenceRepository.SetVehicleOutOfGeofencesAsync(vehicleId, geofenceEventsToMarkAsExited, eventTimestamp);

        return enteredGeofenceIds
            .Select(id => new GeofenceEvent
            {
                Type = GeofenceEventType.Entry,
                GeofenceId = id,
            })
            .Concat(geofenceEventsToMarkAsExited
                .Select(e => new GeofenceEvent
                {
                    Type = GeofenceEventType.Exit,
                    GeofenceId = e.GeofenceId,
                }))
            .ToList();
    }

    internal class GeofenceEvent
    {
        public GeofenceEventType Type { get; set; }
        public Guid GeofenceId { get; set; }
    }

    internal enum GeofenceEventType
    {
        Entry,
        Exit
    }
}