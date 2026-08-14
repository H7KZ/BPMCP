---
layout: home

hero:
  name: InSIS MCP
  text: VŠE study data for your AI assistant
  tagline: Read-only access to courses, timetables and study plans from VŠE InSIS — over the Model Context Protocol.
  actions:
    - theme: brand
      text: Get started
      link: /guide/getting-started
    - theme: alt
      text: How to connect
      link: /guide/connecting

features:
  - title: One URL to connect
    details: 'Add https://bpmcp.vse.cz to any MCP-capable client. No path, no doubling — the bare host is the endpoint.'
  - title: Courses, timetables, study plans
    details: Query VŠE course catalogue, schedule blocks and study-plan structure directly from your assistant.
  - title: Read-only and safe
    details: The server only reads a nightly, university-maintained copy of InSIS. It never writes and owns no personal data.
---

## What is this?

**InSIS MCP** is a remote [Model Context Protocol](https://modelcontextprotocol.io) server that exposes VŠE's **InSIS**
study data — courses, timetables and study plans — to AI assistants such as Claude and Cursor.

Point your client at the endpoint and ask questions in natural language:

> _"Which seminars for 4IZ268 fit a Tuesday-morning schedule?"_

The connection URL is:

```
https://bpmcp.vse.cz
```

Continue to [Getting started](/guide/getting-started) to connect your first client.
