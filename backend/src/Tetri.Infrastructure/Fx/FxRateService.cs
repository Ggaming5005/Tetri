using Npgsql;
using Tetri.Core.Fx;
using Tetri.Core.Ledger;

namespace Tetri.Infrastructure.Fx;

public sealed class FxRateService(HttpClient httpClient, NpgsqlDataSource dataSource, TimeProvider timeProvider)
{
    public const string FeedUrl = "https://nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json/";

    public async Task RefreshAsync(CancellationToken ct)
    {
        var json = await httpClient.GetStringAsync(FeedUrl, ct);
        var rates = NbgRateParser.Parse(json).Where(rate => rate.Currency is "USD" or "EUR").ToArray();
        if (!rates.Any(rate => rate.Currency == "USD") || !rates.Any(rate => rate.Currency == "EUR"))
            throw new InvalidDataException("NBG did not supply both USD and EUR rates.");

        await using var connection = await dataSource.OpenConnectionAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(ct);
        foreach (var rate in rates)
        {
            await using var command = new NpgsqlCommand(
                """
                INSERT INTO fx_rates (currency, rate_to_gel, rate_date, fetched_at)
                VALUES (@currency, @rate, @date, @fetched)
                ON CONFLICT (currency, rate_date) DO NOTHING;
                """, connection, transaction);
            command.Parameters.AddWithValue("currency", rate.Currency);
            command.Parameters.AddWithValue("rate", rate.RateToGel);
            command.Parameters.AddWithValue("date", rate.RateDate);
            command.Parameters.AddWithValue("fetched", timeProvider.GetUtcNow().UtcDateTime);
            await command.ExecuteNonQueryAsync(ct);
        }

        await transaction.CommitAsync(ct);
    }

    public async Task<IReadOnlyList<FxRateValue>> GetCurrentAsync(CancellationToken ct)
    {
        await using var command = dataSource.CreateCommand(
            """
            SELECT DISTINCT ON (currency) currency, rate_to_gel, rate_date
            FROM fx_rates WHERE currency IN ('USD', 'EUR') AND rate_date <= @today
            ORDER BY currency, rate_date DESC;
            """);
        command.Parameters.AddWithValue("today", DateOnly.FromDateTime(timeProvider.GetUtcNow().UtcDateTime));
        await using var reader = await command.ExecuteReaderAsync(ct);
        var rates = new List<FxRateValue>();
        while (await reader.ReadAsync(ct))
            rates.Add(new FxRateValue(reader.GetString(0), reader.GetDecimal(1), reader.GetFieldValue<DateOnly>(2)));
        if (rates.Count != 2)
            throw new DomainException("rates_unavailable", "Exchange rates are unavailable. Try again later.", 503);

        rates.Insert(0, new FxRateValue("GEL", 1m, rates.Min(rate => rate.RateDate)));
        return rates;
    }
}
