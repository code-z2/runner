// Attestor and merchant-registry stub. Real routes arrive with the gateway steps.
const stub = (route: string) =>
  Response.json(
    { error: "not_implemented", route },
    { status: 501, headers: { "content-type": "application/json" } },
  );

const server = Bun.serve({
  port: 8787,
  fetch(request) {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/attestations") {
      return stub("/attestations");
    }
    if (request.method === "GET" && url.pathname === "/merchants") {
      return stub("/merchants");
    }
    if (request.method === "POST" && url.pathname === "/claims/co-sign") {
      return stub("/claims/co-sign");
    }
    return new Response("not_found", { status: 404 });
  },
});

console.log(`runner-api listening on ${server.port}`);
