using Newtonsoft.Json;

namespace AzureLocationTracking.Functions.Data;

public class LatestGeofenceEventDto
{
    [JsonProperty("geofenceId")]
    public Guid GeofenceId { get; set; }
    [JsonProperty("entryTimestamp")]
    public DateTime EntryTimestamp { get; set; }
    [JsonProperty("exitTimestamp")]
    public DateTime? ExitTimestamp { get; set; }
}