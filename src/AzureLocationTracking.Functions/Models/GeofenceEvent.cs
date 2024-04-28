﻿namespace AzureLocationTracking.Functions.Models;

public class GeofenceEvent
{
    public GeofenceEvent(Guid geofenceId, DateTime entryTimestamp, DateTime? exitTimestamp)
    {
        GeofenceId = geofenceId;
        EntryTimestamp = entryTimestamp.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'");
        ExitTimestamp = exitTimestamp?.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'");
    }

    public Guid GeofenceId { get; set; }
    public string EntryTimestamp { get; set; }
    public string ExitTimestamp { get; set; }
}
