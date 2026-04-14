---
name: mcp-best-practices
description: Canonical MCP server quality guide — tool design, descriptions, errors, security, TUI, architecture, anti-patterns. Use when building, reviewing, or auditing any MCP server.
disable-model-invocation: true
---

# MCP Best Practices

Canonical quality guide for building production-grade MCP servers. Synthesized from AWS design guidelines, the MCP specification (2025-11-25), MCPMark benchmark data, Anthropic's mcp-builder skill, and analysis of 7,000+ public servers.

Use this skill when building, reviewing, or auditing any MCP server implementation.

---

## 1. TOOL DESIGN

### 1.1 Tool Count

**5-15 tools per server is optimal. Hard ceiling at 20.**

- GitHub Copilot cut from 40 to 13 tools: +2-5% on benchmarks, -400ms latency.
- Speakeasy study: 107 tools = total failure. 20 tools = 95% success. 10 tools = perfect.
- Context7 has 52.7k stars with **only 2 tools**. Fewer, sharper tools win.
- Apply the 80/20 rule: ~20% of API capabilities handle 80% of user requests.
- If you need more than 20, split into toolsets (GitHub's pattern) or separate servers.

### 1.2 Outcome-Oriented, Not Operation-Oriented

**The single most common MCP design mistake: one tool per REST endpoint.**

- Anti-pattern: `get_customer_by_email` + `list_customer_orders` + `get_order_status` (3 tools, 3 round trips)
- Pattern: `track_latest_order(email)` — returns everything in one call
- At 3 chained steps with 95% per-step accuracy = 85.7% overall success. At 5 steps = 77.4%.
- Design tools around user outcomes, not API operations.

### 1.3 Naming

- **Format**: `^[a-zA-Z0-9_-]{1,64}$` — letters, numbers, underscores, hyphens only
- **Style**: `snake_case` (90%+ of public servers; best tokenization for GPT-4o)
- **Pattern**: `verb_noun` or `service_action_resource` (e.g., `search_issues`, `send_message`)
- **Cursor limit**: 60 chars combined for server+tool name
- Never use generic names (`get_data`, `process_request`). If multiple servers might collide, prefix with service name.
- Stay consistent within a server. Never mix naming styles.

### 1.4 Descriptions

**97.1% of MCP tools have description quality issues. Augmented descriptions improve task success by +5.85 percentage points.**

Write for the LLM, not the human. Six required components:

1. **Purpose** — what does it do
2. **Guidelines** — when and how to use it
3. **Limitations** — what it cannot do and alternatives
4. **Parameter explanation** — format, constraints, valid values
5. **Appropriate length** — 1-2 sentences max, front-load critical info
6. **Examples** — when ambiguity exists

Bad: `"Search for flights"`
Good: `"Search for economy flights between two IATA airport codes on a specific date. Returns up to 20 results sorted by price. Only searches economy class; use premium_flight_search for business/first. Dates must be within 330 days."`

Do NOT put auth requirements, pagination behavior, or rate limits in descriptions — those go in schema or server instructions.

Use `CRITICAL` or `IMPORTANT` keywords for instructions the AI must follow.

**Quality test**: Present tool list to an LLM with 10 sample user requests. If tool selection accuracy is below 90%, refine descriptions.

### 1.5 Parameters

- Use **flat, top-level primitives** with type constraints. Replace `filters: dict` with explicit `email: str, status: Literal["pending", "shipped"]`.
- Mark required parameters explicitly.
- Use constraints: `ge`, `le`, `min_length`, `max_length`, enums, Literal types.
- Use `additionalProperties: false` to reject unexpected input.
- Write parameter descriptions that include constraints, valid values, and AI-specific instructions.

### 1.6 Output Schema

- Define `outputSchema` explicitly when possible. Prevents LLM hallucination of non-existent response fields.
- Return both `structuredContent` (typed JSON) AND `content` (text fallback) for backward compatibility.
- If outputSchema is defined, the server must conform to it.

### 1.7 Tool Annotations (Behavioral Hints)

- `readOnlyHint: true/false` — does not modify state
- `destructiveHint: true/false` — deletes or irreversibly changes data
- `idempotentHint: true/false` — safe to retry without side effects
- `openWorldHint: true/false` — interacts with external systems

These are hints, not guarantees. Clients treat them as untrusted unless from trusted servers.

---

## 2. ERROR HANDLING

### 2.1 Three-Tier Error Model

1. **Transport-Level**: Network timeouts, broken pipes (handled by transport layer)
2. **Protocol-Level**: JSON-RPC 2.0 violations with codes -32700 through -32802
3. **Application-Level**: Business logic failures using `isError: true` flag

### 2.2 The isError Flag

Return errors within result objects, not as protocol-level errors:

```json
{
  "isError": true,
  "content": [{ "type": "text", "text": "What went wrong + what was expected + example of correct input" }]
}
```

Three-part error messages: (1) What went wrong, (2) What was expected, (3) Example of correct input. Suggest ONE or TWO fixes maximum.

Never expose stack traces, internal paths, or sensitive data in error messages.

### 2.3 Recovery Patterns

- **Exponential backoff with jitter**: Only for idempotent operations. 3-5 attempts max.
- **Circuit breaker**: Closed -> Open (after 5 failures) -> Half-Open (test recovery).
- **Graceful degradation**: Return cached data with freshness warnings when dependencies fail.
- **Partial success**: Failed sub-operations don't stop the entire batch (e.g., `read_multiple_files`).
- Include `retry_after` for transient failures.

### 2.4 Anti-Patterns

- Returning plain text instead of JSON-RPC responses
- Returning "Not Found" text that steers LLMs away from processing available data
- Blocking the event loop with synchronous operations
- Silent failures without logging

---

## 3. SECURITY

### 3.1 Transport & Network

- **ALWAYS bind to 127.0.0.1** for local servers, never 0.0.0.0
- TLS 1.2+ for all production traffic. HTTPS required for OAuth URLs.
- Block private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16)
- Use egress proxies for server-side MCP deployments

### 3.2 Authentication

- MCP servers **MUST NOT** accept tokens not explicitly issued for the MCP server
- **Token passthrough is explicitly forbidden** — never forward upstream tokens downstream
- Each server uses service-specific tokens with minimal required scopes
- Session IDs must be cryptographically random (UUIDs). Never sequential.
- MCP Servers **MUST NOT** use sessions for authentication. Verify all inbound requests independently.

**Auth hierarchy** (most to least common):
1. Environment variable (`GITHUB_TOKEN`, `API_KEY`)
2. OAuth device-code flow (best UX for remote servers)
3. Bearer token via Authorization header
4. Zero auth (localhost-only servers like Playwright)

### 3.3 Scope Minimization

- Start with minimal scopes containing only low-risk read operations
- Elevate incrementally via `WWW-Authenticate` challenges
- Never publish all possible scopes in `scopes_supported`
- Never use wildcard scopes (`*`, `all`)

### 3.4 Input Validation

- Validate all inputs against strict schemas before processing
- Sanitize file paths, system commands, URLs, and external identifiers
- Use allowlists, not denylists
- Check for: `exec`, `eval`, `subprocess`, `os.system`, `__import__`, `pickle.loads`

### 3.5 SSRF Prevention

- Validate redirect targets (don't follow redirects to internal resources)
- Pin DNS results between check and use (TOCTOU defense)
- Never implement IP validation manually — attackers exploit encoding tricks

---

## 4. ARCHITECTURE

### 4.1 Single Responsibility

Each MCP server has one clear, well-defined purpose. Do not combine database, file, API, and email functionality in one server. Separate concerns: models, server logic, constants.

### 4.2 Async-First

Use `async/await` for all tool and resource functions. Use `asyncio.gather` / `Promise.all` for concurrent operations. Use async libraries for external API calls.

### 4.3 Configuration

- Externalize all configuration via environment variables with consistent prefix (`MCP_`)
- Never hardcode credentials, timeouts, rate limits, or connection strings
- Validate configuration at startup before accepting requests

### 4.4 Logging

- **Stdout is reserved for JSON-RPC messages only. All logs go to stderr.**
- This is the most common cause of corrupt MCP connections.
- `console.log()` in Node.js writes to stdout and will break stdio transport.
- Use structured JSON logging in production.
- Never log passwords, tokens, API keys, PII, or full payloads.

### 4.5 Framework Selection

- **TypeScript** is the recommended language (best SDK quality, model compatibility, code generation)
- FastMCP dominates Python (24.5k stars, decorator-based)
- Go is emerging for enterprise (GitHub's server is Go)
- Use **MCP Inspector** (`npx @modelcontextprotocol/inspector`) for testing during development

### 4.6 Transport

- **Stdio**: Client launches server as subprocess. Best for local tools.
- **Streamable HTTP**: POST + optional SSE. Replaces deprecated HTTP+SSE.
- Support both stdio AND Streamable HTTP: stdio for local dev, HTTP for remote/shared.
- Validate `Origin` header for HTTP (DNS rebinding prevention).

### 4.7 Response Design

- Return curated, actionable data — not complete API payloads
- Implement pagination: `limit` (default 20-50), `has_more`, `next_offset`, `total_count`
- Never return entire result sets. Large collections overwhelm the context window.

### 4.8 Distribution

Best servers provide multiple install paths:
- `npx @scope/mcp-server` — zero install
- Docker image with volume mounts
- Binary release (Go/Rust servers)
- Remote hosted endpoint
- Config examples for every major client (Claude Desktop, VS Code, Cursor, JetBrains)

### 4.9 Server Instructions

Use the `instructions` field to provide LLM-facing documentation. List available tools with brief descriptions and domain-specific usage tips. Keep under 2KB (Claude Code truncation limit).

---

## 5. TUI & AESTHETICS

### 5.1 TUI Testing (mcp-tui-test patterns)

- **Stream mode**: For CLI tools with sequential text output (pexpect)
- **Buffer mode**: For full ncurses/TUI apps with cursor movement (pexpect + pyte)
- Standard terminal dimensions: 80x24 default, configurable
- Session-based: run multiple TUI apps simultaneously with separate session IDs
- Key tools: `launch_tui`, `send_keys`, `capture_screen`, `expect_text`, `assert_contains`

### 5.2 TUI Design Principles

- Provide clear status feedback showing current MCP operations in progress
- Make tool invocations and data access visible with audit logs
- Display scope of AI operations and potential impacts clearly
- Require explicit user approval for high-risk actions (deletions, payments)
- Interactive parameter forms with built-in validation
- Real-time message tracing for protocol analysis
- Performance timing metrics displayed inline

### 5.3 Debugging Tools

- **MCP Inspector**: Official web interface for direct server testing
- **mcp-probe**: Rust TUI supporting 373+ tool discovery, multi-transport, compliance testing
- **mcp-trace**: TUI for monitoring client-server protocol calls in real time

---

## 6. TESTING & QUALITY

### 6.1 Multi-Layer Testing

- **Unit tests**: Individual components, mock external dependencies
- **Integration tests**: Component interactions, database flows, full request processing
- **Contract tests**: MCP protocol compliance, capability discovery, message format
- **Description quality tests**: Present tools to LLM with 10 requests, target 90%+ selection accuracy
- **Load tests**: 50+ concurrent clients, target >99% success
- **Chaos tests**: Database failures, network partitions, memory pressure

### 6.2 Performance KPIs

- Throughput: >1000 req/s per instance
- Latency P50: <100ms. P99: <500ms
- Error rate: <0.1% under normal conditions
- Availability: >99.9%

### 6.3 Stub Handlers

Implement empty-array stubs for unused primitives to prevent "Method not found" errors:
```python
@app.list_prompts()
async def handle_list_prompts():
    return []
```

---

## 7. ANTI-PATTERNS (Quick Reference)

| Anti-Pattern | Why It Fails |
|---|---|
| API wrapper 1:1 | Tool count explosion, task completion collapse |
| Token passthrough | Broken audit trails, security control bypass |
| `console.log()` on stdout | Corrupts JSON-RPC protocol stream |
| Binding to 0.0.0.0 | Exposes to network, enables DNS rebinding |
| Wildcard scopes (`*`, `all`) | Expanded blast radius on compromise |
| "Not Found" text responses | Steers LLM away from available data |
| Vague tool descriptions | LLM cannot distinguish tools |
| Nested/complex parameters | LLMs handle flat primitives better |
| No output schema | LLM hallucinates response fields |
| Silent failures | Impossible to debug or monitor |
| Making servers "too smart" | Servers should be deterministic, not analysts |
| Exposing giant resources | Overwhelms context window |
| Missing health checks | Cannot detect unhealthy state |
| Generic names across servers | Agent confuses GitHub vs Jira `create_issue` |
| No pagination | Large results blow context budget |

---

## 8. THE THREE-LAYER MODEL

MCP quality lives across three layers. Don't mix them.

| Layer | Where | Contains | Loaded |
|-------|-------|----------|--------|
| **CLAUDE.md** | Project root | Which servers exist, when to prefer each | Every message |
| **Skills** | Skills registry | Workflows, sequencing, quality standards | On-demand |
| **MCP self-docs** | Server instructions + tool descriptions + annotations | How to use tools correctly | Tool Search discovery |

**Servers document the "what"** (tool capabilities, parameters, behaviors).
**Skills document the "how"** (workflows, sequencing, quality standards).
**CLAUDE.md documents the "when"** (which server for which context).

---

## Sources

- [AWS MCP Design Guidelines](https://github.com/awslabs/mcp/blob/main/DESIGN_GUIDELINES.md)
- [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- [MCPMark Benchmark](https://mcpmark.ai)
- [Anthropic mcp-builder Skill](https://github.com/anthropics/skills/blob/main/skills/mcp-builder/SKILL.md)
- [MCP Tool Design: Why Your AI Agent Is Failing (AWS)](https://dev.to/aws-heroes/mcp-tool-design-why-your-ai-agent-is-failing-and-how-to-fix-it-40fc)
- [MCP Is Not the Problem, It's Your Server](https://www.philschmid.de/mcp-best-practices)
- [Docker: Top 5 MCP Server Best Practices](https://www.docker.com/blog/mcp-server-best-practices/)
- [Snyk: 5 Best Practices for Building MCP Servers](https://snyk.io/articles/5-best-practices-for-building-mcp-servers/)
- [MCP Security Best Practices (Official)](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices)
- [SlowMist MCP Security Checklist](https://github.com/slowmist/MCP-Security-Checklist)
- [Microsoft MCP for Beginners](https://github.com/microsoft/mcp-for-beginners)
