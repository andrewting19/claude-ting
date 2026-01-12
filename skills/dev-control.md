# Dev Session Interactive Control

Use this skill to orchestrate another dev session in real-time - sending tasks, monitoring progress, and providing follow-ups without the user attaching.

This is different from `/handoff` where you pass the baton and the user takes over. Here, you remain in control.

## The Control Loop

```
1. Create session (or use existing)
2. Send task
3. Quick read (5-10 lines) - confirm receipt
4. Sleep 30-120s (based on task complexity)
5. Read output - check progress
6. If needed: send follow-up, sleep, read again
7. Repeat until complete
```

## Key: Sleep Before Reading

The other agent needs time to work. Use generous sleeps.

| Task Complexity | Sleep Duration |
|-----------------|----------------|
| Simple read/question | 15-30s |
| Single file change | 30-60s |
| Multi-file implementation | 60-120s |
| Complex feature | 120-180s+ |

## Troubleshooting

**Session seems dead** - Call `list_dev_sessions` (it auto-prunes dead sessions)
