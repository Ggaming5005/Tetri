using FluentAssertions;
using Tetri.Core.Idempotency;

namespace Tetri.UnitTests;

public sealed class CanonicalJsonTests
{
    [Fact]
    public void Hash_ignores_object_property_order_and_whitespace_at_every_depth()
    {
        const string first = """{"recipient":"@nino","amount":{"minor":2500,"currency":"GEL"}}""";
        const string reordered = """
            {
                "amount": { "currency": "GEL", "minor": 2500 },
                "recipient": "@nino"
            }
            """;

        CanonicalJson.Hash(first).Should().Be(CanonicalJson.Hash(reordered));
        CanonicalJson.Hash(first).Should().HaveLength(64);
    }

    [Fact]
    public void Canonicalize_preserves_large_minor_units_exactly()
    {
        const string json = """{"minor":9223372036854775807,"currency":"GEL"}""";

        CanonicalJson.Canonicalize(json).Should().Be("""{"currency":"GEL","minor":9223372036854775807}""");
        CanonicalJson.Hash(json).Should().NotBe(CanonicalJson.Hash("""{"currency":"GEL","minor":9223372036854775806}"""));
    }

    [Fact]
    public void Hash_distinguishes_changed_amounts_and_array_order()
    {
        CanonicalJson.Hash("""{"minor":2500}""").Should().NotBe(CanonicalJson.Hash("""{"minor":2501}"""));
        CanonicalJson.Hash("""{"values":[1,2]}""").Should().NotBe(CanonicalJson.Hash("""{"values":[2,1]}"""));
    }

    [Fact]
    public void Hash_treats_equivalent_string_escapes_as_the_same_value()
    {
        CanonicalJson.Hash("""{"name":"Nino"}""").Should().Be(CanonicalJson.Hash("""{"name":"\u004eino"}"""));
    }

    [Fact]
    public void Canonicalize_sorts_objects_inside_arrays_without_changing_values()
    {
        CanonicalJson.Canonicalize("""{"values":[{"z":null,"a":true},false,"text"]}""")
            .Should().Be("""{"values":[{"a":true,"z":null},false,"text"]}""");
    }

    [Fact]
    public void Canonicalize_rejects_duplicate_properties()
    {
        var action = () => CanonicalJson.Canonicalize("""{"minor":2500,"minor":2501}""");

        action.Should().Throw<System.Text.Json.JsonException>();
    }
}
