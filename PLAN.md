This file is going to be the plan for the project.

## Status: In Progress (paused 2026-06-18)

### Where We Left Off

Completed Tasks 1-4 of 7. Ready to start Task 5 (AI Agent + RAG tools for Workflow 2, Part B).

**Last commit:** `00bcf9a` — "feat: ISQ processing workflow — webhook and question extraction"

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
- **Task 3 (Workflow 1 — Knowledge Ingestion):** COMPLETE
  - `workflows/01-knowledge-ingestion.json` committed
  - Built and tested in n8n UI — all nodes green, 55 chunks inserted into `policy_store`, 25 chunks into `isq_store`
  - **Deviations from original plan (see below for why):**
    - n8n's "Read/Write Files from Disk" node only allows access to `/home/node/.n8n-files` by default (not `/home/node/.n8n/files`) — created a new host directory `~/.n8n-files` and mounted it into the container alongside `~/.n8n`. Restart command is now: `docker run -d -p 5678:5678 -v ~/.n8n:/home/node/.n8n -v ~/.n8n-files:/home/node/.n8n-files n8nio/n8n`
    - `Northstar_Labs_Previous_ISQ_Completed_02.docx` couldn't be parsed by n8n's "Extract from File" node (no DOCX operation). Converted it to `.txt` on the host with `textutil -convert txt` and pointed the Code node's path at the `.txt` version instead.
    - Because PDFs and the one `.txt` file need different "Extract from File" operations, added an **IF node** ("If txt file": `{{ $json.path.endsWith('.txt') }}`) to branch into two Extract from File nodes ("Extract from txt files" / "Extract from pdf files"), recombined with a **Merge** node (Append mode).
    - "Read/Write Files from Disk" and both "Extract from File" operations drop the original JSON fields (`type`, `path`), keeping only file/extracted-content fields. Added two Code nodes to reattach them: "remap type and path" (right after Read/Write Files, references the first Code node by name) and "remap type and path 2" (right after Merge — rebuilds the original pdf-then-txt item order to re-zip `type`/`path` back on, and normalizes the text field since the txt extraction operation outputs `data` instead of `text`).
    - The "Simple Vector Store" node's text splitter is not a direct sub-node — added an **AI → Document Loaders → "Default Data Loader"** node (Mode: "Load Specific Data", JSON Data: `{{ $json.text }}`, Text Splitting: Custom) between the Switch outputs and each vector store, with the Recursive Character Text Splitter (500/50) feeding into the Default Data Loader rather than the vector store directly.
  - Vector store names ended up as `policy_store` / `isq_store` (not `policies-store` / `isqs-store` as originally planned) — **note this when building Task 5/6's Vector Store Tool retrieval nodes, they must reference these exact names.**
- **Task 4 (Workflow 2 Part A — Webhook + Question Extraction):** COMPLETE
  - `workflows/02-isq-processing.json` committed
  - Built and tested in n8n UI — webhook → Extract from File → Config → Basic LLM Chain (Ollama llama3.2) → Code (parse questions) → Respond to Webhook (placeholder, full config in Task 6)
  - Test result: 24 items extracted from the Sunflowers Charity ISQ, each with a populated `question` field (close enough to the plan's expected ~20 — exact count varies by document/LLM run)
  - **Deviations from original plan:**
    - n8n's Webhook node names uploaded multipart file fields with a numeric suffix (e.g. `data0`, not `data`) even for a single file — Extract from File's **Input Binary Field** must be set to `data0`.
    - The **Config** (Set) node strips binary data from the item by default — it only passes through fields you explicitly define. **Node order had to change from the original plan:** Extract from File now runs *before* Config, not after: `Webhook → Extract from File → Config → Basic LLM Chain → Code → Respond to Webhook`. This doesn't affect Task 6's Switch logic since it references the Config node by name (`$('Config')`), not position — but double check the node is actually named `config`/`Config` to match that reference exactly.
    - Basic LLM Chain's "Require Specific Output Format" toggle must be turned **off** — leaving it on expects an Output Parser sub-node, which isn't part of this plan (we parse the raw text manually in the next Code node).
    - To test via curl before the full chain (including Respond to Webhook) exists, a placeholder Respond to Webhook node was added early and connected at the end of the Code node, so test requests don't hang/404.

---

## What's Next

Pick up at **Task 5** in `docs/superpowers/plans/2026-06-17-isq-agent.md`.

Tasks 5–6 involve extending `workflows/02-isq-processing.json` (subagent-driven). Tasks are:
- **Task 5:** Add AI Agent + RAG tools to `workflows/02-isq-processing.json` (Part B)
- **Task 6:** Add LLM Switch + aggregation + response to `workflows/02-isq-processing.json` (Part C)
- **Task 7:** End-to-end test with all three blank ISQs

---

## Environment Setup (to restart tomorrow)

1. **Start Docker Desktop** (open the app, wait for whale icon in menu bar)
2. **Start n8n** (now mounts two volumes — `~/.n8n` for config/credentials, `~/.n8n-files` for documents read by the "Read/Write Files from Disk" node, which only allows access under `/home/node/.n8n-files`):
   ```bash
   docker run -d -p 5678:5678 -v ~/.n8n:/home/node/.n8n -v ~/.n8n-files:/home/node/.n8n-files n8nio/n8n
   ```
3. **Start Ollama:**
   ```bash
   ollama serve
   ```
4. **n8n UI:** http://localhost:5678
5. **Knowledge docs** are already copied to `~/.n8n-files/knowledge/` (note: `.n8n-files`, not `.n8n/files`) — no need to re-run the setup script unless Docker was wiped. One file, `Northstar_Labs_Previous_ISQ_Completed_02.docx`, was converted to `.txt` since n8n can't extract DOCX directly — both the `.docx` and `.txt` versions are in `~/.n8n-files/knowledge/isqs/`, but the workflow points at the `.txt` one.
6. **n8n Credential** `Ollama Local` is already configured (persists in `~/.n8n/`)
7. **Re-run Workflow 1 ("ISQ - Knowledge Ingest")** after every n8n restart — the in-memory vector stores (`policy_store`, `isq_store`) are cleared when the container restarts.

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
