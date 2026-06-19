This file is going to be the plan for the project.

## Status: Stopped for submission (2026-06-19)

### Where We Left Off

Tasks 1-6 of 7 fully complete and committed. Task 7 (end-to-end test with all three blank ISQs) was started but not finished — see below.

**Last commit:** `d591c19` — "docs: update plan with Task 6 learnings, bugs found and fixed, and Anthropic rate-limit findings"

### Task 7 status

- Re-ran Workflow 1 successfully (55 chunks → `policy_store`, 25 chunks → `isq_store`)
- Published Workflow 2 (production webhook live at `/webhook/isq`)
- Ran the full Sunflowers Charity ISQ (24 questions) against the production webhook twice:
  - First run: cancelled manually after noticing `llm_provider` was still set to `anthropic` from earlier testing (avoided an unbudgeted ~£1/~20min Anthropic batch run hitting the known rate-limit issue)
  - Second run (after switching back to `ollama` and republishing): completed (HTTP 200) but **every one of the 24 items failed** to produce a real answer — all fell back to the low-confidence/needs_review/empty-answer state
  - Root cause confirmed to be the same one identified in Task 5: host memory pressure. `vm.swapusage` showed ~8GB/9GB swap in use at the time of the failed run, same as the earlier full-batch failure
- Did **not** complete: Blackridge Wind Energy ISQ test, confidence-flagging spot checks across a real run, or the optional Anthropic LLM-switch full-document test. Decided to stop here for submission rather than keep retrying under known resource constraints.

### What a successful Task 7 run would need

- Free up host memory before retrying (close other apps/browser tabs, confirm `vm.swapusage` is low) — the single-question and 1-2-question tests in Tasks 5/6 prove the pipeline logic itself is correct; the blocker is purely sustained local LLM throughput on this machine
- Re-run with `llm_provider: ollama` for cost-free full-document testing; only use `anthropic` with 1-2 pinned questions at a time unless a Wait/throttle node is added to respect its rate limit
- Once a clean full run succeeds, repeat with the Blackridge Wind Energy ISQ to confirm the response schema holds across documents, and spot-check that every `needs_review: true` answer has a non-null `reason`

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
- **Task 5 (Workflow 2 Part B — AI Agent with RAG Tools):** COMPLETE
  - `workflows/02-isq-processing.json` committed (node names: `AI Agent`, `search_policies`, `search_previous_isqs`, `get_questions` (renamed Task 4 parse node), `format_response` (renamed agent-output parse node))
  - Single pinned-question test passed end-to-end: real tool call → real document retrieved → correct structured JSON answer
  - **Deviations / gotchas from original plan:**
    - The AI Agent's "Source for Prompt (User Message)" field is a dropdown, not free text — must be set to "Define below" (don't toggle `fx` expression mode on the dropdown itself; the actual text field appears *below* it once "Define below" is selected).
    - llama3.2 frequently fails to pass tool arguments in the correct shape (passes a nested object instead of the plain string the Vector Store Tool's schema expects), causing "Cannot embed empty or undefined text" errors. **Fix:** added an explicit instruction to the system message: *"When calling a tool, the input must be a single plain string containing your search query — not a JSON object."* This significantly improved (but did not eliminate) the failure rate.
    - The AI Agent node needs **Settings → On Error: Continue** (not "Stop Workflow"), otherwise one failed tool call/max-iterations error aborts the entire batch instead of just that item.
    - The agent's JSON output sometimes returns `needs_review` as the *string* `"false"`/`"true"` instead of a real boolean — `"false"` is truthy in JS, which would silently break `Task 6`'s `needs_review_count` filter. **Fix:** added `parsed.needs_review = parsed.needs_review === true || parsed.needs_review === 'true';` in the parse Code node (`format_response`) right after the JSON.parse.
    - The `format_response` Code node must be in **"Run Once for Each Item"** mode (it uses `$input.item`, singular) and must `return { json: {...} }` directly — **not** wrapped in an array — since arrays aren't valid returns in that mode.
    - The AI Agent node, like other nodes in this project, drops the original `question` field from the item. Initially fixed in `format_response` by referencing the Task 4 question node by name (`$('get_questions').item.json.question`), but this approach was later found to be fundamentally broken — see Task 6 notes below for the real fix (have the model echo the question back in its JSON output instead).
    - **Known limitation (not fixed, documented instead):** a full 24-question batch run against llama3.2 failed on every single item (all fell back to low-confidence/needs_review) despite the same setup succeeding cleanly in isolation moments earlier. Root cause investigated and traced to **severe host memory pressure** — `vm.swapusage` showed ~8GB/9GB swap in use on a 16GB Mac while Docker (n8n) + Ollama were both active. This is a hardware/resource constraint of the demo machine under sustained sequential LLM load, not a workflow logic bug — the graceful-degradation behavior (low confidence + needs_review) worked exactly as designed. If full-batch reliability matters for the demo, either free up system memory beforehand, or switch `llm_provider` to `anthropic` (Task 6) for the full run, since Claude doesn't share this local resource contention.
- **Task 6 (Workflow 2 Part C — LLM Switch + Aggregation + Response):** COMPLETE
  - `workflows/02-isq-processing.json` committed (node names: `Switch`, `ollama agent` / `Anthropic Agent`, `Anthropic Chat Model`, `format_response` / `format_response_anthropic`, `Merge`, aggregation `Code in JavaScript`)
  - Single pinned-question test passed end-to-end through the full pipeline, including the final aggregated JSON response shape (`processed_at`, `total_questions`, `needs_review_count`, `answers[]`)
  - Anthropic credential (`Anthropic Claude`) added via n8n's Credentials section (not under the gear/Settings menu in this n8n version — it's a separate left-nav item)
  - **Deviations / gotchas from original plan:**
    - Sub-nodes (Embeddings, Chat Models, and even Vector Store Tools) can be **reused/fanned out** to multiple consumers — e.g. one `Embeddings Ollama` node feeding both vector stores, or the same `search_policies`/`search_previous_isqs` tool nodes connected to both the Ollama and Anthropic AI Agents. No need to duplicate them per agent.
    - Initially connected both AI Agents' outputs directly into one shared `format_response` Code node (skipping a dedicated Anthropic parse node + Merge) since it's "just a connection" — this works for simple cases but turned out to be the wrong call here (see pairedItem bug below). Reverted to two separate parse nodes (`format_response`, `format_response_anthropic`) feeding into a proper **Merge** node (Append mode) before aggregation, matching the original plan.
    - **Major bug, found and fixed:** `$('get_questions').item.json.question` (and even `$('get_questions').all()[$itemIndex].json.question`) consistently threw `Cannot read properties of undefined (reading 'pairedItem')` in the parse Code nodes. Root cause: AI Agent (LangChain) nodes don't reliably preserve n8n's internal pairedItem lineage metadata on their output items, so anything relying on that lineage (cross-node `.item` lookups, `$itemIndex`) breaks downstream of an AI Agent, especially with a Switch upstream. **This is not a multi-input-node issue** — it persisted even with single, clean upstream connections. **Real fix:** stopped trying to recover the `question` field from elsewhere entirely. Instead, added `question` to the AI Agent's required JSON output schema (model echoes the exact question back as part of its structured answer), and simplified both parse nodes to just read `parsed.question` directly from the model's own output — no cross-node references needed. This sidesteps n8n's pairedItem system entirely.
    - **Anthropic rate limits on batch runs:** testing the Anthropic path with even 5 pinned questions (not the full 24) hit "max iterations reached" — investigating via the Logs tab traced it to Anthropic's per-account rate limit (30,000 input tokens/minute on this tier), since each agentic call's growing context (system prompt + multi-turn tool results) adds up quickly across several sequential calls with no delay between them. Single-question tests work reliably and cheaply (fractions of a penny, seconds). **Decision: documented as a known limitation, not fixed** — a production fix would mean adding a Wait/throttle node between items on the Anthropic path, or upgrading the Anthropic usage tier. Be deliberate about cost when testing the Anthropic path with more than 1-2 pinned questions — a real full-batch run can cost real money (~£1) and take ~20 minutes once rate-limited retries kick in.
    - Format_response's `try/catch` only catches JSON-parsing failures, not hard node-execution errors (e.g. max-iterations) further upstream — those need `Continue On Fail` set on the AI Agent node itself (done in Task 5) to avoid aborting the whole batch.

---

## What's Next

Pick up at **Task 7** in `docs/superpowers/plans/2026-06-17-isq-agent.md`: end-to-end test with all three blank ISQs.

**Before running full-batch tests:** re-run Workflow 1 first if n8n/Docker has restarted (in-memory vector stores clear on restart). Be cost-aware with the Anthropic path — keep `llm_provider` on `ollama` for routine full-document tests, and only switch to `anthropic` deliberately, ideally with a small pinned subset rather than the full ~20-24 questions, given the rate-limit/cost findings above.

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
