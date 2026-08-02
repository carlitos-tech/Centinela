using System.Globalization;
using System.Text;

namespace Centinela.Application.Common;

/// <summary>
/// Normalización de texto usada por las skills de búsqueda para hacer coincidencias
/// insensibles a mayúsculas/acentos, sin ninguna dependencia externa o de IA.
/// </summary>
public static class TextNormalizer
{
    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        var lower = text.Trim().ToLowerInvariant();
        var decomposed = lower.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(c);
            }
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    public static bool ContainsAny(string normalizedText, IEnumerable<string> keywords)
        => keywords.Any(keyword => normalizedText.Contains(Normalize(keyword), StringComparison.Ordinal));
}
