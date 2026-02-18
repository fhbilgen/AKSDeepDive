using System.Net.Http.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient("opa", http =>
{
    // OPA REST API base address
    http.BaseAddress = new Uri("http://localhost:8181/");
});

var app = builder.Build();

app.MapPost("/authorize", async (AuthorizationRequest req, IHttpClientFactory httpClientFactory) =>
{
    var client = httpClientFactory.CreateClient("opa");

    // OPA expects: { "input": <your input> }
    var opaRequest = new { input = req };

    // Evaluate allow decision
    var allowResp = await client.PostAsJsonAsync("v1/data/authz/allow", opaRequest);
    allowResp.EnsureSuccessStatusCode();

    var allow = await allowResp.Content.ReadFromJsonAsync<OpaDecision<bool>>();
    var isAllowed = allow?.Result == true;

    if (isAllowed)
    {
        return Results.Ok(new { allowed = true });
    }

    // If denied, also ask for reasons (optional but useful)
    var denyResp = await client.PostAsJsonAsync("v1/data/authz/deny", opaRequest);
    denyResp.EnsureSuccessStatusCode();

    var deny = await denyResp.Content.ReadFromJsonAsync<OpaDecision<string[]>>();

    return Results.Json(new { allowed = false, reasons = deny?.Result }, statusCode: 403);
})
.WithName("Authorize");

app.MapGet("/", () =>
    "POST /authorize with JSON body: user, action, resource");

app.Run();

record AuthorizationRequest(User user, string action, string resource);
record User(string role, string department);

// OPA responses look like: { "result": <value> }
record OpaDecision<T>(T Result);
