using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Npgsql;

namespace Tetri.IntegrationTests;

internal sealed class TransferApiFactory(string connectionString, bool authenticateTestUsers = true)
    : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        if (authenticateTestUsers)
        {
            builder.ConfigureTestServices(services => services
                .AddAuthentication(options =>
                {
                    options.DefaultScheme = TestUserAuthenticationHandler.SchemeName;
                    options.DefaultAuthenticateScheme = TestUserAuthenticationHandler.SchemeName;
                    options.DefaultChallengeScheme = TestUserAuthenticationHandler.SchemeName;
                })
                .AddScheme<AuthenticationSchemeOptions, TestUserAuthenticationHandler>(
                    TestUserAuthenticationHandler.SchemeName, _ => { }));
        }
    }

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
                ["RateLimits:TransfersPerMinute"] = "100000"
            }));
        return base.CreateHost(builder);
    }
}

// This scheme exists only in the test assembly and is never registered by the API.
internal sealed class TestUserAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "TestUser";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Guid.TryParse(Request.Headers["X-Test-User"], out var userId))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        var identity = new ClaimsIdentity(
            [new Claim(ClaimTypes.NameIdentifier, userId.ToString("D")), new Claim("sub", userId.ToString("D"))],
            SchemeName);
        return Task.FromResult(AuthenticateResult.Success(
            new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName)));
    }
}
