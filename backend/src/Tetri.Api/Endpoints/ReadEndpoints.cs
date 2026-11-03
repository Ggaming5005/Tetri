using System.Security.Claims;
using Tetri.Core.Queries;
using Tetri.Infrastructure.Queries;

namespace Tetri.Api.Endpoints;

public static class ReadEndpoints
{
    public static void MapReadEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/v1").RequireAuthorization();
        group.MapGet("/me", (ClaimsPrincipal user, BankQueryService queries, CancellationToken token) =>
            queries.ProfileAsync(UserId(user), token)).Produces<ProfileView>();
        group.MapGet("/accounts", (ClaimsPrincipal user, BankQueryService queries, CancellationToken token) =>
            queries.AccountsAsync(UserId(user), token)).Produces<IReadOnlyList<AccountView>>();
        group.MapGet("/users/lookup", (string? handle, BankQueryService queries, CancellationToken token) =>
            queries.LookupAsync(handle, token)).Produces<RecipientView>();
        group.MapGet("/transactions", (ClaimsPrincipal user, BankQueryService queries, CancellationToken token,
            string? cursor = null, int pageSize = 20, string? filter = null) =>
            queries.HistoryAsync(UserId(user), null, cursor, pageSize, filter, token)).Produces<TransactionPage>();
        group.MapGet("/accounts/{id:guid}/transactions", (Guid id, ClaimsPrincipal user, BankQueryService queries,
            CancellationToken token, string? cursor = null, int pageSize = 20, string? filter = null) =>
            queries.HistoryAsync(UserId(user), id, cursor, pageSize, filter, token)).Produces<TransactionPage>();
        group.MapGet("/transactions/{id:guid}", (Guid id, ClaimsPrincipal user, BankQueryService queries, CancellationToken token) =>
            queries.TransactionAsync(UserId(user), id, token)).Produces<TransactionView>();
    }

    private static Guid UserId(ClaimsPrincipal user) => Guid.Parse(
        user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub")!);
}
