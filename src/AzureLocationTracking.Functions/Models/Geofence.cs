using Microsoft.SqlServer.Types;

namespace AzureLocationTracking.Functions.Models;

public class Geofence
{
    public int Id { get; set; }
    public SqlGeography Border { get; set; }
}