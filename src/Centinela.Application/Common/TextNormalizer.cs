using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

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

    /// <summary>
    /// Indica si <paramref name="normalizedText"/> (ya normalizado con <see cref="Normalize"/>)
    /// contiene alguna de las <paramref name="keywords"/> como palabra o frase completa. Usa
    /// límites de palabra para evitar falsos positivos por coincidencia de subcadena arbitraria
    /// (p. ej. que "apagó" -> "apago" no coincida con la palabra clave "pago").
    /// </summary>
    public static bool ContainsAny(string normalizedText, IEnumerable<string> keywords)
        => keywords.Any(keyword => ContainsWholeWordOrPhrase(normalizedText, Normalize(keyword)));

    private static bool ContainsWholeWordOrPhrase(string normalizedText, string normalizedKeyword)
    {
        if (normalizedKeyword.Length == 0)
        {
            return false;
        }

        var pattern = $@"(?<!\w){Regex.Escape(normalizedKeyword)}(?!\w)";
        return Regex.IsMatch(normalizedText, pattern);
    }
}
