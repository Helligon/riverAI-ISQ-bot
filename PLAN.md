This file is going to be the plan for the project. I want to work from the brief in the file: AI Engineer Technical Challenge.pdf

## Status: In Progress (paused 2026-06-17)

### Where We Left Off

Completed Tasks 1 and 2 of 7. Ready to start Task 3 (generating Workflow 1 JSON).

**Last commit:** `78db084` — "chore: environment setup scripts"

---

## What's Been Done

- **Design spec:** `docs/superpowers/specs/2026-06-17-isq-agent-design.md`
- **Implementation plan:** `docs/superpowers/plans/2026-06-17-isq-agent.md` — 7 tasks, follow this exactly
- **Task 1 (Environment Setup):** COMPLETE
  - `scripts/setup-knowledge-docs.sh` — copies docs to `~/.n8n/files/knowledge/` (already run, files are in place)
  - `scripts/test-webhook.sh` — for testing the webhook end-to-end
  - `.gitignore`, `workflows/` directory created
  - Git initialised, first commit made
- **Task 2 (n8n Credentials):** COMPLETE
  - Credential `Ollama Local` added in n8n UI
  - Base URL: `http://host.docker.internal:11434`

---

## What's Next

Pick up at **Task 3** in `docs/superpowers/plans/2026-06-17-isq-agent.md`.

Tasks 3–6 involve generating n8n workflow JSON files (subagent-driven). Tasks are:
- **Task 3:** Generate `workflows/01-knowledge-ingestion.json`
- **Task 4:** Generate `workflows/02-isq-processing.json` (Part A — webhook + question extraction)
- **Task 5:** Add AI Agent + RAG tools to `workflows/02-isq-processing.json` (Part B)
- **Task 6:** Add LLM Switch + aggregation + response to `workflows/02-isq-processing.json` (Part C)
- **Task 7:** End-to-end test with all three blank ISQs

---

## Environment Setup (to restart tomorrow)

1. **Start Docker Desktop** (open the app, wait for whale icon in menu bar)
2. **Start n8n:**
   ```bash
   docker run -it --rm -p 5678:5678 -v ~/.n8n:/home/node/.n8n n8nio/n8n
   ```
3. **Start Ollama:**
   ```bash
   ollama serve
   ```
4. **n8n UI:** http://localhost:5678
5. **Knowledge docs** are already copied to `~/.n8n/files/knowledge/` — no need to re-run the setup script unless Docker was wiped
6. **n8n Credential** `Ollama Local` is already configured (persists in `~/.n8n/`)

---

## Key Architecture Decisions

- **Two n8n workflows:** Knowledge Ingestion (run once) + ISQ Processing (webhook)
- **Agentic RAG:** AI Agent node with two tools — `search_policies` and `search_previous_isqs`
- **Vector stores:** Two named in-memory Simple Vector Stores — `policies-store` and `isqs-store`
- **LLM:** Ollama llama3.2 by default. Switch by changing `llm_provider` in the Config node from `ollama` to `anthropic`
- **Output:** JSON via webhook response — `{ processed_at, total_questions, needs_review_count, answers: [{ question, answer, confidence, needs_review, reason, sources }] }`
- **Embeddings:** Ollama nomic-embed-text (already installed)

---

## Stretch Goals

- **Formatted HTML/PDF output**: Generate a completed questionnaire document mirroring the original ISQ format, ready to send to the client.
- Email attachment trigger
- Persistent vector store (Pinecone) so ingestion only needs to run when docs change
- Support for XLSX questionnaires (currently PDF only)
