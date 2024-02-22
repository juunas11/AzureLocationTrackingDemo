namespace AzureLocationTracking.TrackerDevice;

public class Program
{
    public static void Main(string[] args)
    {
        IHost host = Host.CreateDefaultBuilder(args)
            .ConfigureAppConfiguration((context, config) =>
            {
                config.Sources.Clear();
                config
                    .AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        //["ROUTE_SMOOTHING_ITERATIONS"] = "2",
                        //["MILLIS_BETWEEN_TICKS"] = "1000",
                        ["SIMULATED_DEVICE_COUNT"] = "1",
                    })
                    .AddEnvironmentVariables();

                if (context.HostingEnvironment.IsDevelopment())
                {
                    config.AddUserSecrets<Program>();
                }
            })
            .ConfigureServices(services =>
            {
                services.AddHostedService<Worker>();
                services.AddApplicationInsightsTelemetryWorkerService();
            })
            .Build();

        host.Run();
    }
}
