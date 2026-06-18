#!/bin/bash
# Copies knowledge docs into ~/.n8n-files/knowledge/ so n8n's Docker container
# can read them via the -v ~/.n8n-files:/home/node/.n8n-files volume mount.
# (n8n's "Read/Write Files from Disk" node only allows access under /home/node/.n8n-files.)
set -e

DEST_POLICIES="$HOME/.n8n-files/knowledge/policies"
DEST_ISQS="$HOME/.n8n-files/knowledge/isqs"

mkdir -p "$DEST_POLICIES" "$DEST_ISQS"

cp docs/policies/*.pdf "$DEST_POLICIES/"
cp docs/completed-isqs/*.pdf "$DEST_ISQS/"
cp docs/completed-isqs/*.docx "$DEST_ISQS/"

# n8n's Extract from File node can't parse DOCX directly — convert to plain text.
textutil -convert txt "$DEST_ISQS"/*.docx

echo "Policies copied:"
ls "$DEST_POLICIES"
echo "Completed ISQs copied:"
ls "$DEST_ISQS"
