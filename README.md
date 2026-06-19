# ISQ Agent

An n8n-based agent that fills in blank Information Security Questionnaires (ISQs) using Northstar Labs' policy documents and previous completed ISQs as a knowledge base.

See `PLAN.md` for full project status, architecture decisions, and a detailed log of issues hit and fixed.

## Folder structure

- `workflows/` — n8n workflow exports
  - `01-knowledge-ingestion.json` — run once on n8n startup; chunks and embeds the policy/ISQ documents into two in-memory vector stores (`policy_store`, `isq_store`)
  - `02-isq-processing.json` — webhook-triggered; accepts a blank ISQ PDF, extracts its questions, and uses an AI Agent (RAG over the vector stores) to answer each one
- `docs/policies/`, `docs/completed-isqs/` — Northstar Labs' knowledge base documents (source material for the vector stores)
- `docs/blank-questionnaires/` — sample blank ISQs used to test the processing workflow
- `scripts/setup-knowledge-docs.sh` — copies the knowledge base docs into the folder n8n's Docker container reads from
- `scripts/test-webhook.sh` — sends a blank ISQ PDF to the processing webhook and pretty-prints the response

## Running it

See "Environment Setup" in `PLAN.md` for the Docker/Ollama startup commands and current state of the project.
