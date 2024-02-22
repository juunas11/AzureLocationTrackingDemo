using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data.Common;

namespace AzureLocationTracking.Functions.Data;

public abstract class RepositoryBase : IAsyncDisposable
{
    public RepositoryBase(IConfiguration configuration)
    {
        var sqlConnectionString = configuration["SqlConnectionString"];
        SqlConnection = new SqlConnection(sqlConnectionString);
    }

    protected SqlConnection SqlConnection { get; }

    public Task OpenConnectionAsync(CancellationToken cancellationToken = default)
    {
        return SqlConnection.OpenAsync(cancellationToken);
    }

    public ValueTask<DbTransaction> BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        return SqlConnection.BeginTransactionAsync(cancellationToken);
    }

    public ValueTask DisposeAsync()
    {
        return SqlConnection.DisposeAsync();
    }
}