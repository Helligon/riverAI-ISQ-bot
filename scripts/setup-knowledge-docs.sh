#!/bin/bash
# Copies knowledge docs into ~/.n8n/files/knowledge/ so n8n's Docker container
# can read them via the -v ~/.n8n:/home/node/.n8n volume mount.
set -e

DEST_POLICIES="$HOME/.n8n/files/knowledge/policies"
DEST_ISQS="$HOME/.n8n/files/knowledge/isqs"

mkdir -p "$DEST_POLICIES" "$DEST_ISQS"

cp docs/policies/*.pdf "$DEST_POLICIES/"
cp docs/completed-isqs/*.pdf "$DEST_ISQS/"
cp docs/completed-isqs/*.docx "$DEST_ISQS/"

echo "Policies copied:"
ls "$DEST_POLICIES"
echo "Completed ISQs copied:"
ls "$DEST_ISQS"
