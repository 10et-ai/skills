---
name: voice-ingest
description: Process voice memos and audio files — transcribe with Whisper, classify segments, extract decisions/tasks/context, write journal entries. Use when given an audio file (.m4a, .mp3, .wav, .webm) or when the user says 'voice memo' or 'recording'.
disable-model-invocation: true
---

# Voice Ingest

Process audio files into structured TENET context: decisions, tasks, insights, and action items.

## On Skill Invoke

### Step 1: Transcribe
Use the `Bash` tool to transcribe with Whisper:
```bash
whisper "<file_path>" --model base --output_format json --output_dir /tmp/whisper-out
```
If whisper is not installed: `brew install openai-whisper`

Read the JSON output for timestamped segments.

### Step 2: Classify Each Segment
For each segment, classify as:
- **decision** — a choice was made ("we should...", "let's go with...")
- **task** — an action item ("we need to...", "can you...", "make sure...")
- **context** — background information, discussion, brainstorming
- **insight** — a realization or learning ("I just realized...", "the key thing is...")
- **direction** — strategic guidance ("the priority is...", "focus on...")

### Step 3: Extract Action Items
Pull out concrete tasks with:
- What needs to happen
- Who owns it (if mentioned)
- Priority (if inferable)
- Related files/features (if mentioned)

### Step 4: Write to TENET
For each significant segment:

**Decisions** → `tenet_journal_write` with type "decision"
**Tasks** → File as GitHub Issues or add to journal with type "feature" and status "incomplete"  
**Insights** → `tenet_memory_add` with type "insight"
**Teacup moments** → `tenet_memory_add` with type "teacup" if the speaker describes a specific moment of clarity

### Step 5: Summary
Output a structured summary:
```
## Voice Memo: <title>
Duration: X:XX | Segments: N | Speakers: ...

### Decisions (N)
- Decision 1...

### Action Items (N)  
- [ ] Task 1 — owner: X
- [ ] Task 2

### Key Insights
- Insight 1...

### Context Captured
- Background point 1...
```

## Anti-Patterns
- Don't transcribe and dump raw text — always classify and structure
- Don't skip writing journal entries — the whole point is persistent context
- Don't ignore speaker identification — "Alec said" vs "the team discussed" matters
- Don't create tasks without checking if they already exist as issues
