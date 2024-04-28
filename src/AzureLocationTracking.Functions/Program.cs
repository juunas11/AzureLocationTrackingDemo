using Azure.Core;
using Azure.Identity;
using AzureLocationTracking.Functions.Data;
using AzureLocationTracking.Functions.Services;
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
            })
            .Build();

        await host.RunAsync();
    }
}
