using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FluentAssertions;

namespace Tetri.IntegrationTests;

internal static class TestCredentials
{
    public const string Password = "Integration-passphrase-42";
    public const string SigningKey = "Tetri-integration-tests-only-signing-key-2026";
}

internal static class AuthTestClient
{
    public static async Task<AuthSession> RegisterAsync(
        HttpClient client, string? email = null, string? handle = null, string displayName = "Auth Test")
    {
        var suffix = Guid.CreateVersion7().ToString("N")[16..];
        using var response = await client.PostAsJsonAsync("/api/v1/auth/register", new
        {
            email = email ?? $"{suffix}@example.test",
            displayName,
            handle = handle ?? $"@u{suffix}",
            password = TestCredentials.Password
        });
        response.StatusCode.Should().Be(HttpStatusCode.Created, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<AuthSession>())!;
    }

    public static Task<AuthSession> LoginAsync(HttpClient client, TestUser user) => LoginAsync(client, user.Email);

    public static async Task<AuthSession> LoginAsync(HttpClient client, string email)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/auth/login", new { email, password = TestCredentials.Password });
        response.StatusCode.Should().Be(HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<AuthSession>())!;
    }

    public static async Task<AuthSession> RefreshAsync(HttpClient client, string refreshToken)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken });
        response.StatusCode.Should().Be(HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<AuthSession>())!;
    }

    public static async Task<HttpResponseMessage> SendAuthorizedAsync(HttpClient client, HttpMethod method, string path,
        string accessToken, object? body = null)
    {
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        if (body is not null)
        {
            request.Content = JsonContent.Create(body);
        }

        return await client.SendAsync(request);
    }

    public static async Task<JsonElement> GetJsonAsync(HttpClient client, string path, string accessToken)
    {
        using var response = await SendAuthorizedAsync(client, HttpMethod.Get, path, accessToken);
        response.StatusCode.Should().Be(HttpStatusCode.OK, await response.Content.ReadAsStringAsync());
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    public static async Task<string?> ProblemCodeAsync(HttpResponseMessage response)
    {
        response.Content.Headers.ContentType?.MediaType.Should().Be("application/problem+json");
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        return body.GetProperty("code").GetString();
    }

    public static string TokenHash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
}

internal sealed record AuthUser(Guid Id, string Email, string DisplayName, string Handle);
internal sealed record AuthSession(string AccessToken, string RefreshToken, DateTime ExpiresAt, AuthUser User);
