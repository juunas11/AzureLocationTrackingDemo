using Microsoft.AspNetCore.SignalR.Client;

namespace AzureLocationTracking.SignalRReceiver;

internal class Program
{
    static async Task Main(string[] args)
    {
        var hubEndpoint = "http://localhost:7090/api/signalr";

        var conn = CreateHubConnection(hubEndpoint);

        await conn.StartAsync();

        Console.WriteLine("Connected.");

        await JoinGroupsAsync(conn);

        Console.ReadLine();

        await conn.StopAsync();
    }

    private static async Task JoinGroupsAsync(HubConnection conn)
    {
        await conn.SendAsync("updateMapGridGroups", new int[][]
        {
            [23, 59],
            [23, 60],
            [24, 59],
            [24, 60],
        }, Array.Empty<int[]>());
        Console.WriteLine("Joined groups.");
    }

    static HubConnection CreateHubConnection(string hubEndpoint)
    {
        var connection = new HubConnectionBuilder()
            .WithUrl(hubEndpoint)
            .Build();

        connection.On("locationUpdated", (string trackerId, double latitude, double longitude, long timestamp) =>
        {
            Console.WriteLine($"Location update: '{trackerId}': {latitude} {longitude}");
        });
        connection.On("geofenceEntered", (string trackerId, int geofenceId) =>
        {
            Console.WriteLine($"Geofence enter: '{trackerId}': {geofenceId}");
        });
        connection.On("geofenceExited", (string trackerId, int geofenceId) =>
        {
            Console.WriteLine($"Geofence exit: '{trackerId}': {geofenceId}");
        });

        connection.Closed += ex =>
        {
            Console.Write("The connection is closed.");
            //If you expect non-null exception, you need to turn on 'EnableDetailedErrors' option during client negotiation.
            if (ex != null)
            {
                Console.Write($" Exception: {ex}");
            }
            Console.WriteLine();
            return Task.CompletedTask;
        };

        return connection;
    }
}
