---
name: visa-cli-transact
description: Visa CLI payment integration — atomic agent payments, tenet transact, TAP merchant middleware, payment testing. Use when building services that handle payments, need paid API calls, or want to wire Visa CLI into agent workflows.
disable-model-invocation: true
---

# Visa CLI & tenet transact

Wire real payments into agent workflows. Agents spend money to create products — every image, music track, data query, and API call goes through Visa CLI → Visa network.

## Available Payment Tools

### tenet transact (in-session, Touch ID per call)
```
tenet_transact_image   — AI image via fal.ai ($0.04-0.06)
tenet_transact_music   — Music track via Suno ($0.10)
tenet_transact_price   — On-chain token price via Allium ($0.02)
tenet_transact_run     — Multi-step atomic: "generate hero image and lofi beat" → shopping cart → execute
tenet_transact_status  — Check card, spending limits, daily spend
```

### Visa CLI (command line)
```bash
visa pay <amount> --merchant <name>     # direct payment
visa status                              # card + spending
visa history                             # transaction log
```

## On Skill Invoke

### Step 1: Check Visa CLI Status
```bash
tenet_transact_status
```
Verify: enrolled, card linked, spending limits adequate.

If not enrolled: guide through `visa enroll` flow.

### Step 2: Understand the Use Case

Ask:
- **Building a payment-enabled service?** → TAP merchant middleware setup
- **Need paid API calls in agent workflow?** → tenet transact tools
- **Testing payment flows?** → demo-merchant + demo-agent from tap-stack
- **Running payment red team?** → adversarial-consumers fleet recipe

### Step 3: For Agent Workflows (tenet transact)

When an agent needs to generate content or fetch data:

```
# Single paid call
tenet_transact_image("cyberpunk cityscape at sunset, neon lights")

# Multi-step atomic
tenet_transact_run("generate a hero image for a fintech landing page and a lofi background track")
```

**Budget control:**
- Set max spend per agent run in agent TOML:
  ```toml
  [agent]
  max_spend_usd = 2.00  # stop if cumulative spend exceeds this
  ```
- Or per-recipe:
  ```yaml
  budget: 1.50  # max spend for this recipe run
  ```

### Step 4: For Payment Services (TAP middleware)

Set up Visa Trusted Agent Protocol for your service:

```bash
# 1. Generate agent keypair
tap keygen

# 2. Start local JWKS server
tap dev

# 3. Add middleware to your Next.js/Express app
```

```typescript
// 8-line integration
import { withTap } from '@tap/merchant'

export default withTap(async (req, res) => {
  // req.tap.verified — signature verified
  // req.tap.consumer — consumer recognition object
  // req.tap.payment — payment container
  return res.json({ status: 'ok' })
})
```

### Step 5: For Payment Testing

Run adversarial consumers against your payment flows:

```bash
tenet recipe run fleets/visa-red-team.yaml \
  --param feature="payment verification" \
  --param panel="consumers"
```

This spawns personas (velocity fraud attacker, serial returner, elder user) that stress-test your payment integration.

### Step 6: Transaction Dashboard

After agent runs, check what was spent:

```bash
tenet transact status          # current session spend
tenet transact history         # all transactions
visa history --format json     # raw transaction log
```

## Recipe Integration

Any recipe can include paid steps. Show cost before running:

```yaml
# In recipe YAML
budget: 0.50
activities:
  - Generate hero image ($0.06)
  - Generate background music ($0.10)
  - Fetch competitor pricing ($0.02)
  - Total estimated: $0.18
```

The `tenet recipe run` command shows the budget before executing:
```
  Estimated cost: $0.18 (3 paid API calls)
  Budget: $0.50
  Proceed? [Y/n]
```

## Anti-Patterns
- Don't make paid calls in a loop without budget limits
- Don't skip tenet_transact_status check — verify enrollment first
- Don't hardcode API keys — Visa CLI handles auth via Touch ID
- Don't test payment flows without the adversarial-consumers fleet
