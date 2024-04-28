using Azure.Core;
using Azure.Identity;
using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Functions.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System.Text.Json;

namespace AzureLocationTracking.Functions;
public class Program
{
    public static async Task Main()
    {
        var host = new HostBuilder()
            .ConfigureFunctionsWorkerDefaults()
            .ConfigureServices(services =>
            {
                services.Configure<JsonSerializerOptions>(o =>
                {
                    o.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
                });

                services.AddApplicationInsightsTelemetryWorkerService();
                services.ConfigureFunctionsApplicationInsights();

                services.AddTransient<VehicleRepository>();
                services.AddTransient<GeofenceRepository>();
                services.AddSingleton(serviceProvider =>
                {
                    var environment = serviceProvider.GetRequiredService<IHostEnvironment>();
                    var configuration = serviceProvider.GetRequiredService<IConfiguration>();

                    var isDevelopment = environment.IsDevelopment();

                    TokenCredential credential = isDevelopment
                        ? new AzureCliCredential(new AzureCliCredentialOptions
                        {
                            TenantId = configuration["LocalAuthTenantId"]
                        })
                        : new ManagedIdentityCredential();
                    return credential;
                });
                services.AddSingleton<IotHubDeviceTwinService>();
                services.AddSingleton<DataExplorerRepository>();
                services.AddSingleton<RequestAuthorizer>();
                services.AddSingleton<AzureMapsService>();

                // Copied from https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/best-practice-dotnet#best-practices-for-http-connections
                var socketsHttpHandler = new SocketsHttpHandler();
                // Customize this value based on desired DNS refresh timer
                socketsHttpHandler.PooledConnectionLifetime = TimeSpan.FromMinutes(5);
                // Registering the Singleton SocketsHttpHandler lets you reuse it across any HttpClient in your application
                services.AddSingleton<SocketsHttpHandler>(socketsHttpHandler);

                // Use a Singleton instance of the CosmosClient
                services.AddSingleton<CosmosClient>(serviceProvider =>
                {
                    SocketsHttpHandler socketsHttpHandler = serviceProvider.GetRequiredService<SocketsHttpHandler>();
                    CosmosClientOptions cosmosClientOptions = new CosmosClientOptions()
                    {
                        HttpClientFactory = () => new HttpClient(socketsHttpHandler, disposeHandler: false),
                        ConnectionMode = ConnectionMode.Direct,
                        MaxRetryAttemptsOnRateLimitedRequests = 0,
                    };

                    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
                    var endpoint = configuration["CosmosEndpoint"];
                    var key = configuration["CosmosKey"];
                    
                    return key is null
                        ? new CosmosClient(endpoint, serviceProvider.GetRequiredService<TokenCredential>(), cosmosClientOptions)
                        : new CosmosClient(endpoint, key, cosmosClientOptions);
                });
                services.AddSingleton<CosmosClientWrapper>();
            })
            .Build();

        await host.RunAsync();
    }
}
