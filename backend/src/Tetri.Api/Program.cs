using Microsoft.EntityFrameworkCore;
using Serilog;
using Tetri.Api.Endpoints;
using Tetri.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSerilog(configuration => configuration
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console());

var connectionString = builder.Configuration.GetConnectionString("Database")
    ?? throw new InvalidOperationException("ConnectionStrings:Database must be configured.");
builder.Services.AddDbContext<TetriDbContext>(options => options.UseNpgsql(connectionString));
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    context.ProblemDetails.Extensions.TryAdd("code", "internal_error");
});

var app = builder.Build();

app.UseExceptionHandler();
app.UseSerilogRequestLogging();

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
await app.RunAsync();

public partial class Program;
