# Getting started

**InSIS MCP** is a remote [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server. It gives an AI
assistant read-only access to VŠE **InSIS** study data — courses, timetables and study plans — so you can explore them
in natural language.

## The connection URL

Everything you need is a single URL:

```
https://bpmcp.vse.cz
```

That bare host **is** the MCP endpoint — there is no `/mcp` path to append. The same address opens this documentation in
a browser and answers MCP clients that connect to it; the server tells the two apart automatically.

## Requirements

- An MCP-capable client — for example [Claude](https://claude.ai), Claude Desktop, or [Cursor](https://cursor.com).
- Nothing to install locally: the server is remote and hosted by VŠE.

## What you can ask

Once connected, you can ask your assistant things like:

- _"Find elective courses taught in English worth at least 6 ECTS."_
- _"Show the timetable blocks for 4IZ268 this semester."_
- _"What are the compulsory courses in the Applied Informatics study plan?"_

## Data freshness

The server reads a **nightly** copy of InSIS (refreshed each morning), so answers are at most about a day old. This
suits course, timetable and study-plan data, which changes on a semester cadence rather than intraday.

Next: [connect a client →](/guide/connecting)
