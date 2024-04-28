using Microsoft.Azure.Cosmos.Spatial;

namespace AzureLocationTracking.Functions.Models;

public class Geofence
{
    public int Id { get; set; }
    public Polygon Border { get; set; }
    public string Name { get; set; }
}