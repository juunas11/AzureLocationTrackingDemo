namespace AzureLocationTracking.Functions.Data;

public class GeofenceEventDto
{
    public int GeofenceId { get; set; }
    public DateTime EntryTimestamp { get; set; }
    public DateTime? ExitTimestamp { get; set; }
}
