using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Serilog;
using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using Tetri.Api.Background;
using Tetri.Api.Configuration;
using Tetri.Api.Endpoints;
using Tetri.Api.Errors;
using Tetri.Core.Auth;
using Tetri.Core.Entities;
using Tetri.Core.Fx;
using Tetri.Infrastructure.Auth;
using Tetri.Infrastructure.Fx;
using Tetri.Infrastructure.Idempotency;
using Tetri.Infrastructure.Ledger;
using Tetri.Infrastructure.Persistence;
using Tetri.Infrastructure.Queries;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSerilog(configuration => configuration
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console());

var connectionString = builder.Configuration.GetConnectionString("Database")
    ?? throw new InvalidOperationException("ConnectionStrings:Database must be configured.");
builder.Services.AddSingleton(_ =>
{
    var databaseOptions = new NpgsqlConnectionStringBuilder(connectionString)
    {
        MaxPoolSize = builder.Configuration.GetValue("Database:MaxPoolSize", 64)
    };
    return NpgsqlDataSource.Create(databaseOptions.ConnectionString);
});
builder.Services.AddDbContext<TetriDbContext>((services, options) =>
    options.UseNpgsql(services.GetRequiredService<NpgsqlDataSource>()));
builder.Services.AddScoped<LedgerService>();
builder.Services.AddScoped<IdempotencyService>();
builder.Services.AddScoped<BankQueryService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddSingleton<IPasswordHasher<User>, PasswordHasher<User>>();
builder.Services.AddOptions<JwtOptions>().Bind(builder.Configuration.GetSection("Jwt"))
    .Validate(options => Encoding.UTF8.GetByteCount(options.SigningKey ?? "") >= 32,
        "Jwt:SigningKey must contain at least 32 bytes.")
    .ValidateOnStart();
builder.Services.AddOptions<FxOptions>().Bind(builder.Configuration.GetSection("Fx"))
    .Validate(options => options.Spread >= 0 && options.Spread < 1, "Fx:Spread must be between 0 and 1, excluding 1.")
    .Validate(options => double.IsFinite(options.RefreshHours) && options.RefreshHours > 0 && options.RefreshHours <= 168,
        "Fx:RefreshHours must be greater than zero and at most 168.")
    .ValidateOnStart();
builder.Services.AddHttpClient<FxRateService>(client => client.Timeout = TimeSpan.FromSeconds(15));
builder.Services.AddScoped<FxService>();
builder.Services.AddHostedService<FxRateRefreshService>();
builder.Services.AddTetriRateLimits(builder.Configuration);
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNameCaseInsensitive = false;
    options.SerializerOptions.UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow;
    options.SerializerOptions.NumberHandling = JsonNumberHandling.Strict;
    options.SerializerOptions.RespectRequiredConstructorParameters = true;
});
builder.Services.TryAddSingleton<TimeProvider>(TimeProvider.System);
builder.Services.TryAddSingleton<IIdempotencyTestHooks, NoOpIdempotencyTestHooks>();
builder.Services.AddHostedService<LedgerMaintenanceService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.MapInboundClaims = false;
    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
            if (!Guid.TryParse(context.Principal?.FindFirstValue("sub"), out var userId) || userId == Guid.Empty ||
                !Guid.TryParse(context.Principal?.FindFirstValue("sid"), out var familyId) || familyId == Guid.Empty)
            {
                context.Fail("Invalid session claims.");
            }

            return Task.CompletedTask;
        },
        OnChallenge = async context =>
        {
            context.HandleResponse();
            context.Response.Headers.WWWAuthenticate = "Bearer";
            await Results.Problem(
                title: "Sign in required",
                detail: "Sign in to continue.",
                statusCode: StatusCodes.Status401Unauthorized,
                extensions: new Dictionary<string, object?> { ["code"] = "unauthorized" })
                .ExecuteAsync(context.HttpContext);
        }
    };
});
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<JwtTokenService>((options, tokens) => options.TokenValidationParameters = tokens.CreateValidationParameters());
builder.Services.AddAuthorization();
builder.Services.AddOpenApi();
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    context.ProblemDetails.Extensions.TryAdd("code", "internal_error");
});

var app = builder.Build();

app.UseSerilogRequestLogging();
app.UseExceptionHandler();
app.UseStatusCodePages(async context =>
{
    var status = context.HttpContext.Response.StatusCode;
    var (title, code) = status switch
    {
        400 => ("Check the request", "invalid_request"),
        401 => ("Sign in required", "unauthorized"),
        403 => ("Access denied", "forbidden"),
        404 => ("Not found", "not_found"),
        _ => ("Request failed", "request_failed")
    };
    await Results.Problem(
        title: title,
        statusCode: status,
        extensions: new Dictionary<string, object?> { ["code"] = code })
        .ExecuteAsync(context.HttpContext);
});
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

if (builder.Configuration.GetValue<bool>("Database:ApplyMigrations"))
{
    await using var scope = app.Services.CreateAsyncScope();
    var database = scope.ServiceProvider.GetRequiredService<TetriDbContext>();
    await database.Database.MigrateAsync();
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapGet("/openapi", () => Results.Redirect("/openapi/v1.json"))
        .ExcludeFromDescription();
}

app.MapHealthEndpoints();
app.MapTransferEndpoints();
app.MapAuthEndpoints();
app.MapReadEndpoints();
app.MapFxEndpoints();
await app.RunAsync();

public partial class Program;
