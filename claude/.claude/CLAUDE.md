# Global Claude Code Guidelines

## Git Identity
Git is configured via `gh auth setup-git`. Use `gh auth setup-git` if git complains about identity.
- Name: Sam Chung
- Email: tieoneease@gmail.com
- GitHub: tieoneease

## Sub-Agents
- Keep code edits in main context. Delegate exploration and research to sub-agents to protect the context window.
- Use sub-agents with WebSearch/WebFetch for doc lookups. Save reusable findings to memory.

## Research
- Prefer official docs, API references, and RFCs over blogs and Stack Overflow.
- Follow documented, idiomatic patterns over novel approaches.
