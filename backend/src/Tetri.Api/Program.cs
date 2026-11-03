using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Serilog;
using Tetri.Api.Background;
using Tetri.Api.Endpoints;
using Tetri.Infrastructure.Idempotency;
using Tetri.Infrastructure.Ledger;
using Tetri.Infrastructure.Persistence;

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
builder.Services.TryAddSingleton<TimeProvider>(TimeProvider.System);
builder.Services.TryAddSingleton<IIdempotencyTestHooks, NoOpIdempotencyTestHooks>();
builder.Services.AddHostedService<LedgerMaintenanceService>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.Events = new JwtBearerEvents
    {
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
builder.Services.AddAuthorization();
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    context.ProblemDetails.Extensions.TryAdd("code", "internal_error");
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseSerilogRequestLogging();
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
await app.RunAsync();

public partial class Program;
