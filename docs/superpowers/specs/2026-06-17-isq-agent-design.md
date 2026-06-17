# ISQ Agent — Design Spec
**Date:** 2026-06-17
**Status:** Approved

## Overview

An n8n workflow that accepts a blank ISQ PDF via webhook, extracts the questions, searches Northstar Labs' knowledge base using an AI Agent, generates answers, and returns a structured JSON response with confidence scores and review flags.

## Tech Stack

| Component | Choice | Notes |
|---|---|---|
| Workflow platform | n8n (Docker, localhost:5678) | Self-hosted |
| LLM | Ollama llama3.2 (default) | Switchable to Anthropic Claude |
| Embeddings | Ollama nomic-embed-text | Local, no API cost |
| Vector store | n8n Simple Vector Store (in-memory) | Upgrade path: Pinecone |
| Input | Webhook (POST with PDF) | |
| Output | JSON | |

## Two-Workflow Architecture

### Workflow 1 — Knowledge Ingestion (run once on startup)

Triggered manually. Loads all knowledge documents from `~/.n8n/files/knowledge/` (mounted into the Docker container), extracts text, chunks, embeds, and populates the in-memory vector store.

**Knowledge documents:**
- `docs/policies/` — 6 Northstar Labs policy PDFs (Information Security, Secure SDLC, Acceptable Use, BC/DR, Incident Response, Data Protection)
- `docs/completed-isqs/` — 3 previous completed ISQs (2 PDFs, 1 DOCX)

**Steps:**
1. Manual Trigger
2. Read files from disk (loop over knowledge directory)
3. Extract text from PDF / DOCX
4. Recursive character text splitter (chunk size: 500 tokens, overlap: 50)
5. Embed chunks — Ollama `nomic-embed-text`
6. Insert into one of two named Simple Vector Store instances: `policies-store` (policy docs) or `isqs-store` (completed ISQs)

### Workflow 2 — ISQ Processing (webhook triggered)

Triggered by a POST request containing a PDF file. Extracts questions, runs them through an AI Agent with RAG tools, and returns a completed JSON response.

**Steps:**
1. Webhook trigger — `POST /webhook/isq` with PDF binary
2. **Config node** — Set node containing `{ "llm_provider": "ollama" }`. Change this one value to switch providers.
3. Extract text from PDF
4. LLM call — extract questions as a JSON array from the PDF text
5. Split to items — one item per question
6. **Loop: for each question:**
   - AI Agent node (llama3.2 or Claude, determined by Config node via Switch)
   - Tools available to the agent:
     - `search_policies` — vector similarity search against policy document chunks
     - `search_previous_isqs` — vector similarity search against completed ISQ chunks
   - Agent system prompt instructs it to: prefer policy docs, supplement with previous ISQs, report confidence, and explicitly state when evidence is insufficient
7. Aggregate all question results into a single array
8. Return JSON via webhook response

## LLM Switching

In n8n, the LLM is a sub-node wired directly into the AI Agent node — it cannot be swapped at runtime. The Switch node therefore routes to two parallel AI Agent nodes that are identically configured (same system prompt, same tools) but each wired to a different LLM sub-node:

- **Ollama path** — AI Agent + Ollama Chat Model (`llama3.2`, base URL `http://host.docker.internal:11434`)
- **Anthropic path** — AI Agent + Anthropic Chat Model (API key credential)

Both paths merge back into the aggregation step. Switching providers = changing one field (`llm_provider`) in the Config node at the top of the workflow.

## Output Schema

```json
{
  "questionnaire": "Sunflowers_Charity_Supplier_ISQ_Questionnaire.pdf",
  "processed_at": "2026-06-17T10:00:00Z",
  "answers": [
    {
      "question": "Do you maintain a formal Information Security Policy?",
      "answer": "Yes. Northstar Labs maintains a formal Information Security Policy reviewed annually and approved by senior leadership. It covers access control, encryption, acceptable use, asset management, and incident management.",
      "confidence": "high",
      "needs_review": false,
      "reason": null,
      "sources": ["Northstar_Labs_Information_Security_Policy.pdf", "Northstar_Labs_Previous_ISQ_Completed_01.pdf"]
    },
    {
      "question": "Please provide details of any relevant certifications.",
      "answer": "No certification details were found in the available policy documents or previous questionnaires.",
      "confidence": "low",
      "needs_review": true,
      "reason": "No evidence of certifications (e.g. ISO 27001, Cyber Essentials) found in knowledge base. Human review required.",
      "sources": []
    }
  ]
}
```

## AI Agent System Prompt

The agent receives this instruction per question:

> You are completing a supplier information security questionnaire on behalf of Northstar Labs.
> For the question provided, use the available tools to search the company's policy documents and previous completed ISQs.
> Rules:
> - Prefer answers grounded in official policy documents
> - Supplement with previous ISQ responses where helpful
> - Be concise and professional — appropriate for a client/vendor security questionnaire
> - If you cannot find sufficient evidence, say so clearly and set confidence to "low"
> - Never invent or assume facts not present in the retrieved documents
> Return a JSON object with: answer, confidence (high/medium/low), needs_review (boolean), reason (string or null), sources (array of document names).

## Answer Rules

- **High confidence**: Direct policy statement found and/or confirmed in a previous ISQ
- **Medium confidence**: Relevant context found but not an exact policy statement
- **Low confidence**: Little or no relevant content retrieved — `needs_review: true`, `reason` explains what's missing

## File Access

Knowledge docs are copied to `~/.n8n/files/knowledge/` on the host so they're accessible to the n8n Docker container (via the `-v ~/.n8n:/home/node/.n8n` volume mount).

## Stretch Goals

- Formatted HTML/PDF output mirroring the original ISQ layout, ready to send to clients
- Email attachment trigger (in addition to webhook)
- Persistent vector store (Pinecone) so ingestion only needs to run when docs change
- Support for XLSX questionnaires (currently PDF only)
