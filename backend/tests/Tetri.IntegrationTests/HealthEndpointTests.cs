using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Npgsql;
using Xunit;

namespace Tetri.IntegrationTests;

public sealed class HealthEndpointTests(PostgresFixture database) : IClassFixture<PostgresFixture>
{
    [Fact]
    public async Task Health_returns_ok_when_postgres_is_available()
    {
        await using var factory = new TetriApiFactory(database.ConnectionString);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/v1/health");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        body.GetProperty("status").GetString().Should().Be("ok");
        body.GetProperty("database").GetString().Should().Be("ok");
    }

    [Fact]
    public async Task Health_returns_generic_problem_details_when_database_is_unavailable()
    {
        var unavailableDatabase = $"missing_{Guid.NewGuid():N}";
        var connection = new NpgsqlConnectionStringBuilder(database.ConnectionString)
        {
            Database = unavailableDatabase,
            Timeout = 2,
            CommandTimeout = 2,
            Pooling = false
        };
        await using var factory = new TetriApiFactory(connection.ConnectionString);
        using var client = factory.CreateClient();

        using var response = await client.GetAsync("/api/v1/health");

        response.StatusCode.Should().Be(HttpStatusCode.ServiceUnavailable);
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/problem+json");
        var text = await response.Content.ReadAsStringAsync();
        using var body = JsonDocument.Parse(text);
        body.RootElement.GetProperty("status").GetInt32().Should().Be(503);
        body.RootElement.GetProperty("code").GetString().Should().Be("database_unavailable");
        text.Should().NotContain(unavailableDatabase).And.NotContain("Npgsql").And.NotContain("Host=");
    }

    private sealed class TetriApiFactory(string connectionString) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
        }

        protected override IHost CreateHost(IHostBuilder builder)
        {
            // Program reads the connection string before Build, so supply it as host configuration.
            builder.ConfigureHostConfiguration(configuration => configuration.AddInMemoryCollection(
                new Dictionary<string, string?>
                {
                    ["ConnectionStrings:Database"] = connectionString,
                    ["Database:ApplyMigrations"] = "false",
                    ["Jwt:SigningKey"] = TestCredentials.SigningKey,
                    ["Jwt:Issuer"] = "Tetri",
                    ["Jwt:Audience"] = "Tetri.Mobile",
                    ["Fx:FetchEnabled"] = "false"
                }));
            return base.CreateHost(builder);
        }
    }
}
