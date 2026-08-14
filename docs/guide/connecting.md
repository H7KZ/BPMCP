# Connecting a client

Every MCP client needs the same thing: the server URL.

```
https://bpmcp.vse.cz
```

Add it as a **remote** (HTTP / streamable) MCP server. You do **not** append `/mcp` or any other path — the bare host is
the endpoint.

## Claude

1. Open **Settings → Connectors** (or **Custom connectors**).
2. Choose **Add custom connector**.
3. Paste `https://bpmcp.vse.cz` as the server URL.
4. Approve the connection when prompted.

## Cursor

Add the server to your MCP configuration:

```json
{
	"mcpServers": {
		"insis": {
			"url": "https://bpmcp.vse.cz"
		}
	}
}
```

## Other clients

Any client that speaks the **streamable HTTP** MCP transport works the same way — register `https://bpmcp.vse.cz` as a
remote server. If your client asks for a transport type, choose HTTP (not stdio); there is no command to run, only the
URL.

## Troubleshooting

- **The browser shows documentation, not data.** That is expected — opening the URL in a browser is a `GET` request and
  returns this site. MCP clients connect with `POST`, and the server routes them to the endpoint instead.
- **Connection refused or unauthorized.** Make sure you registered it as a _remote / HTTP_ server and used the exact URL
  above, with no trailing path.
