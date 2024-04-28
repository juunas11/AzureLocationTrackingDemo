using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.Extensions.Configuration;
using HttpRequestData = Microsoft.Azure.Functions.Worker.Http.HttpRequestData;

namespace AzureLocationTracking.Functions.Services;

public class RequestAuthorizer
{
    private readonly string _azureAdClientId;
    private readonly string _azureAdAppScope;
    private readonly ConfigurationManager<OpenIdConnectConfiguration> _openIdConfigurationManager;

    public RequestAuthorizer(IConfiguration configuration)
    {
        _azureAdClientId = configuration["AzureAdClientId"];
        _azureAdAppScope = configuration["AzureAdAppScope"];
        var azureAdTenantId = configuration["AzureAdTenantId"];
        _openIdConfigurationManager = new ConfigurationManager<OpenIdConnectConfiguration>(
            $"https://login.microsoftonline.com/{azureAdTenantId}/v2.0/.well-known/openid-configuration", new OpenIdConnectConfigurationRetriever());
    }

    public async Task<bool> AuthorizeRequestAsync(HttpRequestData req)
    {
        if (!req.Headers.TryGetValues("Authorization", out var authHeaderValues))
        {
            return false;
        }

        if (!authHeaderValues.Any())
        {
            return false;
        }

        var token = authHeaderValues.First().Split(' ')[1];
        
        var tokenValidationParameters = new TokenValidationParameters
        {
            ConfigurationManager = _openIdConfigurationManager,
            ValidAudiences = new[]
            {
                _azureAdClientId,
                _azureAdAppScope.Substring(0, _azureAdAppScope.LastIndexOf('/')),
            },

        };
        var tokenHandler = new JwtSecurityTokenHandler();
        try
        {
            var result = await tokenHandler.ValidateTokenAsync(token, tokenValidationParameters);
            if (!result.IsValid)
            {
                return false;
            }

            var claims = result.Claims;

            if (
                !claims.TryGetValue("http://schemas.microsoft.com/identity/claims/scope", out var scopeValue)
                || scopeValue is not string scope
                || scope != _azureAdAppScope.Substring(_azureAdAppScope.LastIndexOf('/') + 1))
            {
                return false;
            }

            return true;
        }
        catch
        {
            return false;
        }
    }
}
