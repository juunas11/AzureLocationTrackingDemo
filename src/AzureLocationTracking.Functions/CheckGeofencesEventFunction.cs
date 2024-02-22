using System.Data.Common;
using System.Text.Json;
using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Messages;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.SqlServer.Types;

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
        var log = functionContext.GetLogger<CheckGeofencesEventFunction>();
        var exceptions = new List<Exception>();
        var signalRMessageActions = new List<SignalRMessageAction>();

        await _geofenceRepository.OpenConnectionAsync();

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
        var trackerId = ev.Id;
        var location = SqlGeography.Point(ev.Lat, ev.Lng, 4326);

        var signalRMessageActions = new List<SignalRMessageAction>();

        await using (var transaction = await _geofenceRepository.BeginTransactionAsync())
        {
            var geofenceEvents = await CheckGeofencesAsync(trackerId, location, ev.Ts, transaction);
            var longitudeNumber = (int)Math.Floor(ev.Lng);
            var latitudeNumber = (int)Math.Floor(ev.Lat);

            foreach (var geofenceEvent in geofenceEvents)
            {
                signalRMessageActions.Add(new SignalRMessageAction(
                    geofenceEvent.Type == GeofenceEventType.Entry ? "geofenceEntered" : "geofenceExited",
                    new object[]
                    {
                        trackerId.ToString(),
                        geofenceEvent.GeofenceId,
                    }
                ){
                    GroupName = $"grid:{longitudeNumber}:{latitudeNumber}",
                });
            }

            await transaction.CommitAsync();
        }

        return signalRMessageActions;
    }

    private async Task<List<GeofenceEvent>> CheckGeofencesAsync(
        Guid trackerId,
        SqlGeography location,
        DateTime eventTimestamp,
        DbTransaction transaction)
    {
        var (enteredGeofenceIds, exitedGeofenceIds) = await _geofenceRepository
            .GetEnteredAndExitedGeofenceIdsAsync(trackerId, location, eventTimestamp, transaction);

        await _geofenceRepository.AddLocationTrackerInGeofencesAsync(trackerId, enteredGeofenceIds, eventTimestamp, transaction);

        await _geofenceRepository.SetLocationTrackerOutOfGeofencesAsync(trackerId, exitedGeofenceIds, eventTimestamp, transaction);

        return enteredGeofenceIds
            .Select(id => new GeofenceEvent
            {
                Type = GeofenceEventType.Entry,
                GeofenceId = id,
            })
            .Concat(exitedGeofenceIds
                .Select(id => new GeofenceEvent
                {
                    Type = GeofenceEventType.Exit,
                    GeofenceId = id,
                }))
            .ToList();
    }

    internal class GeofenceEvent
    {
        public GeofenceEventType Type { get; set; }
        public int GeofenceId { get; set; }
    }

    internal enum GeofenceEventType
    {
        Entry,
        Exit
    }
}