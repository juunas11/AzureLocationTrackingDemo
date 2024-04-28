using Microsoft.Azure.Cosmos.Spatial;
using Newtonsoft.Json;

namespace AzureLocationTracking.Functions.Data;

public class GeofenceDto
{
    [JsonProperty("id")]
    public string Id { get; set; }
    [JsonProperty("border")]
    public Polygon Border { get; set; }
    [JsonProperty("name")]
    public string Name { get; set; }
}
