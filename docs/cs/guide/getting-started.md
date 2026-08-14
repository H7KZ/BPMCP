# Začínáme

**InSIS MCP** je vzdálený server [Model Context Protocol](https://modelcontextprotocol.io) (MCP). Poskytuje AI
asistentovi read-only přístup ke studijním datům VŠE **InSIS** — předmětům, rozvrhům a studijním plánům — abyste je
mohli prozkoumávat přirozeným jazykem.

## Adresa pro připojení

Vše, co potřebujete, je jediná adresa:

```
https://bpmcp.vse.cz
```

Tento samotný host **je** MCP endpoint — žádnou cestu `/mcp` nepřidáváte. Stejná adresa otevře v prohlížeči tuto
dokumentaci a zároveň obslouží MCP klienty, kteří se k ní připojí; server obojí rozliší automaticky.

## Požadavky

- MCP klient — například [Claude](https://claude.ai), Claude Desktop nebo [Cursor](https://cursor.com).
- Nic se neinstaluje lokálně: server je vzdálený a hostovaný VŠE.

## Na co se můžete ptát

Po připojení se můžete asistenta ptát například:

- _„Najdi volitelné předměty vyučované anglicky za alespoň 6 ECTS."_
- _„Zobraz rozvrhové bloky pro 4IZ268 v tomto semestru."_
- _„Jaké jsou povinné předměty ve studijním plánu Aplikovaná informatika?"_

## Aktuálnost dat

Server čte **noční** kopii InSIS (obnovovanou každé ráno), takže odpovědi jsou staré nanejvýš zhruba jeden den. To
vyhovuje datům o předmětech, rozvrzích a studijních plánech, která se mění v rytmu semestru, nikoli během dne.

Dále: [připojení klienta →](/cs/guide/connecting)
