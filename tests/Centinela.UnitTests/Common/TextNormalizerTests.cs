using Centinela.Application.Common;

namespace Centinela.UnitTests.Common;

public class TextNormalizerTests
{
    [Theory]
    [InlineData("Café", "cafe")]
    [InlineData("  Lámpara Aurora  ", "lampara aurora")]
    [InlineData("¿Cuánto cuesta?", "¿cuanto cuesta?")]
    public void Normalize_RemovesAccentsAndLowercasesAndTrims(string input, string expected)
    {
        Assert.Equal(expected, TextNormalizer.Normalize(input));
    }

    [Fact]
    public void ContainsAny_MatchesWholeWordKeyword()
    {
        var normalized = TextNormalizer.Normalize("¿Cuál es la política de pagos?");

        Assert.True(TextNormalizer.ContainsAny(normalized, ["pago", "pagos"]));
    }

    [Fact]
    public void ContainsAny_DoesNotMatchKeywordAsArbitrarySubstring()
    {
        var normalized = TextNormalizer.Normalize("La lámpara se apagó, ¿qué hago?");

        Assert.False(TextNormalizer.ContainsAny(normalized, ["pago"]));
    }

    [Fact]
    public void ContainsAny_MatchesMultiWordPhraseAcrossWordBoundaries()
    {
        var normalized = TextNormalizer.Normalize("¿Cuánto cuesta la Lámpara Aurora?");

        Assert.True(TextNormalizer.ContainsAny(normalized, ["cuánto cuesta"]));
    }

    [Fact]
    public void ContainsAny_IsAccentAndCaseInsensitive()
    {
        var normalized = TextNormalizer.Normalize("¿Cuál es la GARANTÍA del producto?");

        Assert.True(TextNormalizer.ContainsAny(normalized, ["garantia"]));
    }

    [Fact]
    public void ContainsAny_ReturnsFalse_WhenNoKeywordMatches()
    {
        var normalized = TextNormalizer.Normalize("Hola, buenos días");

        Assert.False(TextNormalizer.ContainsAny(normalized, ["pago", "devolución", "garantía"]));
    }
}
