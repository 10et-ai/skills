---
name: subway-browser
description: Control the user's real browser via Subway mesh — navigate, read, screenshot, inspect, fill forms, watch DOM changes
disable-model-invocation: true
triggers:
  - browser
  - browse
  - web
  - look at
  - open page
  - read page
  - screenshot
  - inspect element
  - fill form
  - /browser
---

# /browser — Subway Browser Agent

Control the user's real Chrome browser through the Subway P2P mesh. The Subway Chrome Extension registers as an agent — you send it commands via `subway_call`, it executes in the real browser and returns results.

**This is not headless Puppeteer.** This is the user's actual browser — logged in, with cookies, extensions, and real session state.

## Architecture

```
You (Pi agent)  ──subway_call──►  Chrome Extension (browser agent)  ──►  Real browser
                ◄──rpc_response──                                    ◄──  DOM/tabs/screenshots
```

All commands go through: `subway_call` → target: extension agent name → method: `"browser"` → payload: `{"action": "...", ...params}`

## Setup Check

**Step 1: Find the browser agent on the mesh**

```
subway_resolve browser.relay
```

If not found, try the user's configured extension name. Common names:
- `browser.relay`
- `{username}.relay` (if extension is registered under their name)

Ask the user: "What name is your Subway Chrome Extension registered as?"

**Step 2: If extension not reachable, fall back to chrome-cli**

```bash
which chrome-cli
```

chrome-cli can do basic operations without the extension:
```bash
chrome-cli list tabs          # List open tabs
chrome-cli open <url>         # Open URL in new tab
chrome-cli info               # Active tab info
chrome-cli source             # Page source of active tab
chrome-cli execute <js>       # Run JS in active tab
```

**Step 3: If neither available, suggest setup**

```
To use browser tools, either:

1. Install the Subway Chrome Extension (recommended):
   → Load from subway-extension/ directory in chrome://extensions
   → Configure agent name in popup
   → Extension connects to relay.subway.dev

2. Install chrome-cli (basic fallback):
   → brew install chrome-cli
```

## Commands Reference

### Get browser status (orientation)
```
subway_call browser.relay browser {"action": "status"}
```
Returns: active tab (url, title), last action, connected agents, command count.
**Use this first** to orient yourself — know what page the user is on before asking.

### Navigate to URL
```
subway_call browser.relay browser {"action": "navigate", "url": "https://example.com", "waitFor": "load"}
```
waitFor options:
- `"load"` (default) — wait for page load complete
- `"none"` — fire and forget
- `"networkidle"` — wait for network to settle (good for SPAs)
- `"selector:.my-element"` — wait for specific element to appear

### Read page content
```
subway_call browser.relay browser {"action": "read_page"}
```
Returns: text content, headings, links, meta.

**With CSS selector** (saves context window — use this!):
```
subway_call browser.relay browser {"action": "read_page", "selector": ".main-content"}
```
Returns only the text/headings/links within that element.

**With max length:**
```
subway_call browser.relay browser {"action": "read_page", "selector": "article", "max_length": 10000}
```

### Screenshot
```
subway_call browser.relay browser {"action": "screenshot"}
```
Returns: data URL (base64 PNG).

### Execute JavaScript
```
subway_call browser.relay browser {"action": "execute_js", "code": "document.title"}
```
Returns: serialized result of the expression.

### Click element
```
subway_call browser.relay browser {"action": "click", "selector": "button.submit"}
```

### Fill input
```
subway_call browser.relay browser {"action": "fill", "selector": "input[name=email]", "value": "hello@example.com"}
```

### List all tabs
```
subway_call browser.relay browser {"action": "list_tabs"}
```
Returns: all open tabs with id, title, url, active status.

### Switch to tab
```
subway_call browser.relay browser {"action": "switch_tab", "tab_id": 123}
```
Or by URL match:
```
subway_call browser.relay browser {"action": "switch_tab", "url": "github.com"}
```

### Get form state
```
subway_call browser.relay browser {"action": "form_state", "selector": "form#checkout"}
```
Returns: all input fields with names, types, current values, labels, required/disabled.

### Page snapshot (accessibility tree)
```
subway_call browser.relay browser {"action": "snapshot"}
```
Returns: headings, links, buttons, forms, images, landmarks, inputs — semantic page structure without the full DOM.

### Inspect element (interactive)
```
subway_call browser.relay browser {"action": "inspect"}
```
Activates inspector mode in the browser. User hovers and clicks an element. Returns: tag, classes, selector, text, HTML, computed styles, ARIA attributes, bounding rect.

**Note:** This requires user interaction — use when you need the user to point at something specific.

### Watch for DOM changes
```
subway_call browser.relay browser {"action": "watch", "selector": ".notifications", "topic": "browser.notifications"}
```
Sets up a MutationObserver. Changes broadcast to the Subway topic. Subscribe to receive them:
```
subway_subscribe browser.notifications
```

### Stop watching
```
subway_call browser.relay browser {"action": "unwatch", "selector": ".notifications"}
```

## Multi-Tab Workflows

Read from a specific tab without switching focus:
```
subway_call browser.relay browser {"action": "read_page", "tab_id": 456, "selector": ".pricing-table"}
```

Compare two pages:
1. `list_tabs` to see what's open
2. `read_page` with `tab_id` on each
3. Process both results

## Fallback: chrome-cli

When the extension isn't connected, use chrome-cli via bash:

```bash
# List tabs (returns id:title pairs)
chrome-cli list tabs

# Get active tab info (id, title, url, loading state)
chrome-cli info
chrome-cli info -t <tab-id>

# Open a URL (new tab)
chrome-cli open "https://example.com"

# Open URL in specific existing tab
chrome-cli open "https://example.com" -t <tab-id>

# Get full page HTML source
chrome-cli source
chrome-cli source -t <tab-id>

# Execute JavaScript (fire-and-forget — DOES NOT return values)
chrome-cli execute "document.querySelector('button').click()"

# Close a tab
chrome-cli close -t <tab-id>

# Activate a tab
chrome-cli activate -t <tab-id>
```

**IMPORTANT: chrome-cli execute does NOT return values to stdout.** It runs the JS but you can't read the result. For reading page data, use `chrome-cli source` to get HTML, then parse it. Or use Chrome headless `--dump-dom`.

chrome-cli limitations vs extension:
- **execute doesn't return values** — can only trigger actions, not read data
- No CSS selector scoping on read (full HTML source only)
- No mutation watching
- No interactive inspect
- No form state snapshot
- No waitFor on navigate
- No screenshots (use Chrome headless for that)
- Tab IDs use format `[window_id:tab_id]` — use the tab_id part with `-t`

## Fallback: Chrome Headless

For screenshots without the extension:
```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --screenshot=/tmp/page.png \
  --window-size=1280,720 "https://example.com"
```

For reading page content without the extension (returns rendered DOM):
```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --dump-dom --disable-gpu "https://example.com"
```

Chrome headless is useful for:
- Screenshots of pages you're not browsing
- Getting rendered DOM (JS-executed) from URLs
- CI/automation where no real browser session exists

## Best Practices

1. **Always check status first** — `{"action": "status"}` tells you what page the user is on
2. **Use selector scoping** — `read_page` with a selector returns focused content, not 50KB dumps
3. **Use snapshot for orientation** — before interacting, get the page structure
4. **waitFor on navigate** — SPAs need `"networkidle"` or `"selector:..."`, not just `"load"`
5. **Tab awareness** — check `list_tabs` before navigating — the page might already be open
6. **Inspect for ambiguity** — when you're not sure what the user means, use `inspect` and let them point

## Common Workflows

### Read an article
```
status → navigate (if needed) → read_page with selector "article" or ".content"
```

### Fill a form
```
status → form_state to see what fields exist → fill each field → click submit
```

### Compare competitors
```
list_tabs → read_page tab A with selector → read_page tab B with selector → analyze
```

### Monitor for changes
```
watch selector → subscribe to topic → agent gets notified on changes
```

### User points at something
```
inspect → user clicks element → agent gets full DOM context → process
```
