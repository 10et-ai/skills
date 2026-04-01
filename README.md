# TENET Skills Registry

> Skills that improve themselves through usage.

This is the community skill registry for [TENET](https://10et.ai). Skills are instructions that help AI agents do specific tasks better — brand design, content creation, deployment, code optimization.

## Install a Skill

```bash
tenet skills install pretext
tenet skills install brand-architect
tenet skills list --available
```

## Browse Skills

| Category | Skills |
|----------|--------|
| **Core** | hud, end, context, eval, pivot, search, viz |
| **Creative** | brand-architect, content-creator, founder-video, web-architect, x-algorithm |
| **Design** | pretext, frontend-design, web-builder |
| **Frameworks** | react-best-practices, remotion-best-practices, tailwind-v4, r3f-best-practices |
| **Tools** | fly-deploy, debug, agent-browser |

## How Skills Work

1. Agent reads `SKILL.md` when a task matches the skill's trigger
2. Follows the instructions to produce output
3. Session journal captures what worked / what didn't
4. `tenet skills harvest` extracts learnings from journals
5. `tenet skills improve` runs a build agent to make the skill better
6. `tenet skills publish` shares improvements back here

## Add a Skill

1. Create `skills/<your-skill>/SKILL.md`
2. Add frontmatter: `name`, `description`, `triggers`
3. Add to `registry.json`
4. Open a PR

Or from your project:
```bash
tenet skills publish my-skill
```

## Skill Format

```markdown
---
name: my-skill
description: What this skill helps agents do
triggers:
  - keyword that activates this skill
  - another trigger phrase
---

# My Skill

Instructions for the agent...

## Learnings (auto-accumulated)

- Things learned from real usage
```

## Links

- [TENET CLI](https://github.com/10et-ai/cli)
- [Docs](https://docs.10et.ai)
- [Website](https://10et.ai)
