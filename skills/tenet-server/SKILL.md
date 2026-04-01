---
name: tenet-server
description: Connect to TENET Server — authenticate, check status, sync data between CLI and remote server
triggers:
  - tenet login
  - tenet server
  - server status
  - connect to server
  - authenticate
  - /server
---

# TENET Server Connection

Connect the local CLI to a TENET Server instance for remote memory, journals, and agent coordination.

## Auth Flow

The CLI authenticates with the server using JWT Bearer tokens. Three ways to authenticate:

### 1. Platform Login (recommended)
```bash
tenet login --platform
```
Opens browser → device code → server issues JWT → stored locally.

### 2. Direct Token (agents/CI)
```bash
# Generate token on server, then:
export TENET_PLATFORM_URL=https://your-server.example.com
# Token stored by tenet login
```

### 3. Check Status
```bash
tenet login          # Shows current auth status
tenet login --force  # Re-authenticate
```

## When to Use This Skill

Use when you see:
- `Not authenticated with TENET Server` errors
- Need to sync local journals/memory to remote server
- Setting up a new machine to connect to an existing TENET Server
- Agent needs server access for MCP tools

## How Auth Works

1. `tenet login --platform` registers a device with the server
2. Server returns a device code (e.g., "ABC-123")
3. User enters code in browser at `{SERVER_URL}/api/cli/register-device`
4. Server links device → returns JWT
5. CLI stores JWT in `~/.config/tenet/config.json` (via `Conf` library)
6. All subsequent API calls include `Authorization: Bearer {token}`

## Server API Endpoints

The TENET Server exposes these APIs (all require Bearer auth except login):

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/cli/tenet-login` | GET/POST | Auth endpoint info / authenticate |
| `/api/tenet/journal` | GET/POST | Read/write journal entries |
| `/api/tenet/memory/search` | POST | Semantic memory search |
| `/api/tenet/memory/add` | POST | Add memory entry |
| `/api/tenet/mcp` | GET | SSE stream (MCP connection + tools) |
| `/api/tenet/mcp` | POST | Invoke MCP tool |
| `/api/tenet/voice/ingest` | POST | Upload audio for transcription |
| `/api/tenet/workspaces` | GET | List workspaces |

## Agent Usage

Agents can check server connectivity and auth:

```typescript
import { tenetServer } from '../utils/tenet-server.js'

// Check if authenticated
if (!tenetServer.isServerAuthenticated()) {
  console.log('Run: tenet login --platform')
}

// Check server health
const health = await tenetServer.checkServerHealth()
if (!health.ok) {
  console.log(`Server unreachable at ${health.url}: ${health.error}`)
}

// Make API calls
const entries = await tenetServer.journal.list('workspace-id')
await tenetServer.journal.create('workspace-id', 'Title', 'Content')
const results = await tenetServer.memory.search('workspace-id', 'query')
```

## Environment Variables

| Var | Default | Purpose |
|-----|---------|---------|
| `TENET_PLATFORM_URL` | `https://tenet.ai` | Server URL |
| `TENET_SERVER_URL` | `http://localhost:3000` | Fallback server URL |
| `JWT_SECRET` | dev default | Must match server's JWT_SECRET |

## Troubleshooting

**"Not authenticated"** → Run `tenet login --platform`

**"Server unreachable"** → Check `TENET_PLATFORM_URL` or `TENET_SERVER_URL` env var. For local dev: `docker compose up` in jfl-platform.

**"Invalid token"** → Token expired or JWT_SECRET mismatch. Run `tenet login --force`.
