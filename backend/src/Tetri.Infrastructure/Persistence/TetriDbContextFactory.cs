using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Tetri.Infrastructure.Persistence;

public sealed class TetriDbContextFactory : IDesignTimeDbContextFactory<TetriDbContext>
{
    public TetriDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__Database")
            ?? "Host=localhost;Database=tetri;Username=tetri";
        var options = new DbContextOptionsBuilder<TetriDbContext>()
            .UseNpgsql(connectionString)
            .Options;

        return new TetriDbContext(options);
    }
}
