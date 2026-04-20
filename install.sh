#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/lead-nurturing/workflow/workflow.json"
ENV_FILE="$SCRIPT_DIR/.env"

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

# ── 1. Vérifier que n8n est accessible ────────────────────────────────────────
echo "→ Vérification de n8n sur $N8N_URL ..."

if ! curl -sf --max-time 5 "$N8N_URL/healthz" > /dev/null 2>&1; then
  echo "✗ n8n n'est pas accessible sur $N8N_URL"
  echo "  Assurez-vous que n8n est démarré, puis relancez ce script."
  exit 1
fi

echo "✓ n8n est en ligne."

# ── 2. Vérifier que le fichier workflow existe ────────────────────────────────
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "✗ Fichier introuvable : $WORKFLOW_FILE"
  exit 1
fi

# ── 3. Construire les headers d'authentification ──────────────────────────────
AUTH_HEADER=""
if [[ -n "$N8N_API_KEY" ]]; then
  AUTH_HEADER="X-N8N-API-KEY: $N8N_API_KEY"
else
  echo "⚠  N8N_API_KEY non définie — tentative sans authentification."
  echo "   Si l'import échoue, renseignez N8N_API_KEY dans votre fichier .env"
fi

# ── 4. Importer le workflow via l'API REST ────────────────────────────────────
echo "→ Import du workflow dans n8n ..."

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$N8N_URL/rest/workflows" \
  -H "Content-Type: application/json" \
  ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
  -d @"$WORKFLOW_FILE")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
  echo "✗ Échec de l'import (HTTP $HTTP_CODE)"
  echo "  Réponse : $HTTP_BODY"
  exit 1
fi

# ── 5. Extraire l'ID et afficher le lien ─────────────────────────────────────
WORKFLOW_ID=$(echo "$HTTP_BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$WORKFLOW_ID" ]]; then
  # fallback : certaines versions de n8n retournent id comme entier
  WORKFLOW_ID=$(echo "$HTTP_BODY" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
fi

echo ""
echo "✓ Workflow importé avec succès !"
echo ""
if [[ -n "$WORKFLOW_ID" ]]; then
  echo "  URL : $N8N_URL/workflow/$WORKFLOW_ID"
else
  echo "  Retrouvez le workflow dans : $N8N_URL/workflows"
fi
echo ""
echo "Prochaine étape : configurez vos credentials SMTP et Notion dans n8n,"
echo "puis activez le workflow."
