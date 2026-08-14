# Připojení klienta

Každý MCP klient potřebuje totéž: adresu serveru.

```
https://bpmcp.vse.cz
```

Přidejte ji jako **vzdálený** (HTTP / streamable) MCP server. Cestu `/mcp` ani žádnou jinou **nepřidáváte** — endpoint
je samotný host.

## Claude

1. Otevřete **Nastavení → Konektory** (nebo **Vlastní konektory**).
2. Zvolte **Přidat vlastní konektor**.
3. Vložte `https://bpmcp.vse.cz` jako adresu serveru.
4. Po výzvě připojení potvrďte.

## Cursor

Přidejte server do své MCP konfigurace:

```json
{
  "mcpServers": {
    "insis": {
      "url": "https://bpmcp.vse.cz"
    }
  }
}
```

## Ostatní klienti

Jakýkoli klient, který umí **streamable HTTP** MCP transport, funguje stejně — zaregistrujte `https://bpmcp.vse.cz` jako
vzdálený server. Pokud se klient ptá na typ transportu, zvolte HTTP (ne stdio); není co spouštět, jen adresa URL.

## Řešení potíží

- **Prohlížeč zobrazí dokumentaci, ne data.** To je v pořádku — otevření adresy v prohlížeči je požadavek `GET` a vrátí
  tento web. MCP klienti se připojují přes `POST` a server je nasměruje na endpoint.
- **Odmítnuté nebo neautorizované připojení.** Ujistěte se, že jste server zaregistrovali jako _vzdálený / HTTP_ a
  použili přesně výše uvedenou adresu bez koncové cesty.
