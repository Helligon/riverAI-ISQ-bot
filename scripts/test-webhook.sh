#!/bin/bash
# Sends a blank ISQ PDF to the webhook and pretty-prints the JSON response.
# Usage: ./scripts/test-webhook.sh [path-to-pdf]
set -e

PDF="${1:-docs/blank-questionnaires/Sunflowers_Charity_Supplier_ISQ_Questionnaire.pdf}"

echo "Sending: $PDF"
curl -s -X POST http://localhost:5678/webhook/isq \
  -F "data=@$PDF" \
  | python3 -m json.tool
