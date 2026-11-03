using Microsoft.AspNetCore.Diagnostics;
using Tetri.Core.Ledger;

namespace Tetri.Api.Errors;

public sealed class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException domain)
        {
            return false;
        }

        await Results.Problem(
            title: domain.StatusCode >= 500 ? "Service unavailable" : "Request couldn't be completed",
            detail: domain.Message,
            statusCode: domain.StatusCode,
            extensions: new Dictionary<string, object?> { ["code"] = domain.Code })
            .ExecuteAsync(context);
        return true;
    }
}
