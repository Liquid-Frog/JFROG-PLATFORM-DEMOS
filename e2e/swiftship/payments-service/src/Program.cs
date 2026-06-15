var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI();

app.MapGet("/health", () => new { status = "UP", service = "payments-service" });

app.MapPost("/payments", (PaymentRequest req) =>
{
    // VULN-SEED (JAS Secrets): hardcoded payment gateway API key
    // Fix: inject from environment variable or Azure Key Vault
    var gatewayKey = "pk_live_51NxSOMDo-not-use-this-in-production";
    return new
    {
        payment_id = $"PAY-{Guid.NewGuid():N}"[..12],
        status = "authorized",
        amount = req.Amount,
        currency = req.Currency,
    };
});

app.Run();

record PaymentRequest(decimal Amount, string Currency, string CardToken);
