using Azure.Core;
using Azure.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace AzureLocationTracking.Functions.Services;

public class AzureMapsService
{
    private static AccessToken CachedReadToken;
    private static DateTimeOffset CachedReadTokenRenewTime;
    private readonly TokenCredential _tokenCredential;

    public AzureMapsService(
        IHostEnvironment environment,
        IConfiguration configuration)
    {
        _tokenCredential = environment.IsDevelopment()
            ? new AzureCliCredential(new AzureCliCredentialOptions
            {
                TenantId = configuration["LocalAuthTenantId"]
            })
            : new ManagedIdentityCredential(new ResourceIdentifier(configuration["MapsIdentityResourceId"]));
    }

    public async Task<string> GetRenderTokenAsync()
    {
        if (CachedReadTokenRenewTime > DateTimeOffset.UtcNow)
        {
            return CachedReadToken.Token;
        }

        var scopes = new[] { "https://atlas.microsoft.com/.default" };
        var result = await _tokenCredential.GetTokenAsync(new TokenRequestContext(scopes), CancellationToken.None);
        CachedReadToken = result;
        CachedReadTokenRenewTime = result.ExpiresOn - TimeSpan.FromMinutes(4);

        return result.Token;
    }
}
