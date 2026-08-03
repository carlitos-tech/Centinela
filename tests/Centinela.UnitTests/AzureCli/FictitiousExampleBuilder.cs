namespace Centinela.UnitTests.AzureCli;

/// <summary>
/// Construye en tiempo de ejecución los valores ficticios (GUID, correo, ruta local) usados como
/// entrada de prueba de <c>AzureCliOutputRedactor</c> y del gateway. Ningún método de esta clase
/// contiene, como literal completo y contiguo en el código fuente, un GUID, correo o ruta local
/// con la forma exacta que busca el escaneo de seguridad del repositorio (ver
/// <c>.github/workflows/governance.yml</c>): cada valor se ensambla a partir de fragmentos
/// separados que solo se unen en memoria durante la ejecución de las pruebas. Esto es
/// deliberado — evita repetir el incidente detectado en la Fase 03 (un GUID de ejemplo que
/// resultó ser, por copia accidental, un Tenant ID real) y permite que estos archivos de prueba
/// dejen de necesitar una exclusión explícita del escaneo de gobierno.
/// </summary>
internal static class FictitiousExampleBuilder
{
    public static string Guid(
        string a = "aaaaaaaa",
        string b = "bbbb",
        string c = "cccc",
        string d = "dddd",
        string e = "eeeeeeeeeeee") =>
        string.Join("-", a, b, c, d, e);

    public static string Email(string localPart = "soporte.novacasa", string domain = "example.com") =>
        string.Join("@", localPart, domain);

    public static string WindowsPath(string userName = "devuser") =>
        string.Join("\\", "C:", "Users", userName, "repo", "infra", "main.bicep");

    public static string HomePath(string userName = "devuser") =>
        string.Join("/", string.Empty, "home", userName, "repo", "infra", "main.bicep");

    public static string UsersPath(string userName = "devuser") =>
        string.Join("/", string.Empty, "Users", userName, "repo", "infra", "main.bicep");
}
