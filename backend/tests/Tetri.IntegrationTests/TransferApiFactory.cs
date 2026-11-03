using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Npgsql;

namespace Tetri.IntegrationTests;

internal sealed class TransferApiFactory(
    string connectionString, bool useRealRateLimits = false, string environment = "Testing")
    : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.UseEnvironment(environment);

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.ConfigureHostConfiguration(configuration => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:Database"] = new NpgsqlConnectionStringBuilder(connectionString)
                {
                    MaxPoolSize = 64
                }.ConnectionString,
                ["Database:ApplyMigrations"] = "false",
                ["Jwt:SigningKey"] = TestCredentials.SigningKey,
                ["Jwt:Issuer"] = "Tetri",
                ["Jwt:Audience"] = "Tetri.Mobile",
                ["Fx:FetchEnabled"] = "false",
                ["RateLimits:AuthPermitLimit"] = useRealRateLimits ? "5" : "100000",
                ["RateLimits:HandlePermitLimit"] = useRealRateLimits ? "20" : "100000",
                ["RateLimits:MoneyPermitLimit"] = useRealRateLimits ? "30" : "100000"
            }));
        return base.CreateHost(builder);
    }
}
