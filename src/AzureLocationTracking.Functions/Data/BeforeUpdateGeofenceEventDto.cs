using Newtonsoft.Json;

namespace AzureLocationTracking.Functions.Data;

public class BeforeUpdateGeofenceEventDto
{
    [JsonProperty("id")]
    public string Id { get; set; }
    [JsonProperty("geofenceId")]
    public Guid GeofenceId { get; set; }
}