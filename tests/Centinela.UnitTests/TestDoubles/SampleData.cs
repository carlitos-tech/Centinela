using Centinela.Domain.Entities;
using Centinela.Domain.Enums;

namespace Centinela.UnitTests.TestDoubles;

/// <summary>Datos ficticios mínimos de NovaCasa S.A.S. usados como fixtures en pruebas unitarias.</summary>
public static class SampleData
{
    public static Product LamparaAurora => new()
    {
        Code = "LAM-001",
        Name = "Lámpara Aurora",
        Category = "Iluminación",
        Description = "Lámpara de mesa ficticia para pruebas.",
        Price = 89000m,
        Availability = ProductAvailability.InStock,
        Features = ["Luz cálida", "Base regulable"],
        UseCases = ["Escritorio de lectura", "Mesa de noche"],
        Warnings = [],
        Source = "Catálogo local NovaCasa S.A.S. - LAM-001",
    };

    public static Product CocinaEconomica => new()
    {
        Code = "COC-001",
        Name = "Set de Ollas Esencial",
        Category = "Cocina",
        Description = "Set de ollas ficticio para pruebas.",
        Price = 45000m,
        Availability = ProductAvailability.InStock,
        Features = ["Antiadherente"],
        UseCases = ["Cocina diaria"],
        Warnings = [],
        Source = "Catálogo local NovaCasa S.A.S. - COC-001",
    };

    public static Product CocinaPremiumFueraDePresupuesto => new()
    {
        Code = "COC-004",
        Name = "Set de Ollas Premium",
        Category = "Cocina",
        Description = "Set de ollas premium ficticio para pruebas.",
        Price = 320000m,
        Availability = ProductAvailability.InStock,
        Features = ["Acero inoxidable"],
        UseCases = ["Cocina gourmet"],
        Warnings = [],
        Source = "Catálogo local NovaCasa S.A.S. - COC-004",
    };

    public static Product MuebleAgotado => new()
    {
        Code = "MUE-001",
        Name = "Repisa Modular",
        Category = "Muebles",
        Description = "Repisa modular ficticia para pruebas, sin existencias.",
        Price = 150000m,
        Availability = ProductAvailability.OutOfStock,
        Features = ["Modular"],
        UseCases = ["Almacenamiento"],
        Warnings = [],
        Source = "Catálogo local NovaCasa S.A.S. - MUE-001",
    };

    public static BusinessPolicy PoliticaDevoluciones => new()
    {
        Topic = "devoluciones",
        Title = "Política de devoluciones",
        Content = "Las devoluciones ficticias de NovaCasa S.A.S. se aceptan dentro de 30 días con factura.",
        Keywords = ["devolución", "devoluciones"],
        Source = "Políticas locales NovaCasa S.A.S. - devoluciones",
    };
}
