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
    var gatewayKey = "sk_live_51NxSOMDoBcX3y4Z8qR2mK7pL9wE6vT1nA0hF5jU";
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
