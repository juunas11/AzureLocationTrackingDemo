namespace AzureLocationTracking.Messages;
public class LocationUpdateEvent
{
    public Guid Id { get; set; }
    public double Lng { get; set; }
    public double Lat { get; set; }
    public DateTime Ts { get; set; }
}
