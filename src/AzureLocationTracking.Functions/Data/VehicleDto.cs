using Microsoft.Azure.Cosmos.Spatial;
using Newtonsoft.Json;

namespace AzureLocationTracking.Functions.Data;

public class VehicleDto
{
    [JsonProperty("id")]
    public string Id { get; set; }
    [JsonProperty("latestLocation")]
    public Point LatestLocation { get; set; }
}
