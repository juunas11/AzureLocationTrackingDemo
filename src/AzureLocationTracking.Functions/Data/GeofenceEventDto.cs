﻿using Newtonsoft.Json;

namespace AzureLocationTracking.Functions.Data;

public class GeofenceEventDto
{
    [JsonProperty("id")]
    public string Id { get; set; }
    [JsonProperty("vehicleId")]
    public Guid VehicleId { get; set; }
    [JsonProperty("geofenceId")]
    public Guid GeofenceId { get; set; }
    [JsonProperty("entryTimestamp")]
    public DateTime EntryTimestamp { get; set; }
    [JsonProperty("exitTimestamp")]
    public DateTime? ExitTimestamp { get; set; }
}
