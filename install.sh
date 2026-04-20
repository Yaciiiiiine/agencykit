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

# ── 3. Déterminer le header d'authentification ───────────────────────────────
AUTH_HEADER=""

try_import() {
  local header="$1"
  curl -s -w "\n%{http_code}" \
    -X POST "$N8N_URL/api/v1/workflows" \
    -H "Content-Type: application/json" \
    ${header:+-H "$header"} \
    -d @"$WORKFLOW_FILE"
}

if [[ -z "$N8N_API_KEY" ]]; then
  echo "⚠  N8N_API_KEY non définie — tentative sans authentification."
fi

# ── 4. Importer le workflow en testant les deux formats d'auth ────────────────
echo "→ Import du workflow dans n8n ..."

HTTP_BODY=""
HTTP_CODE=""

for CANDIDATE in \
  "X-N8N-API-KEY: $N8N_API_KEY" \
  "Authorization: Bearer $N8N_API_KEY"
do
  # Skip auth candidates when no key provided
  if [[ -z "$N8N_API_KEY" ]] && [[ "$CANDIDATE" != "" ]]; then
    CANDIDATE=""
  fi

  RESPONSE=$(try_import "$CANDIDATE")
  HTTP_BODY=$(echo "$RESPONSE" | head -n -1)
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then
    AUTH_HEADER="$CANDIDATE"
    break
  fi

  # Only loop when we have a key to try
  [[ -z "$N8N_API_KEY" ]] && break
done

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
  echo "✗ Échec de l'import (HTTP $HTTP_CODE)"
  echo "  Réponse : $HTTP_BODY"
  if [[ -n "$N8N_API_KEY" ]]; then
    echo "  Les deux formats de header ont été testés sans succès :"
    echo "    • X-N8N-API-KEY"
    echo "    • Authorization: Bearer"
    echo "  Vérifiez que votre clé API est correcte et que les droits sont suffisants."
  fi
  exit 1
fi

if [[ -z "$N8N_API_KEY" ]]; then
  echo "✓ Authentification : aucune clé (accès libre)"
elif [[ "$AUTH_HEADER" == X-N8N-API-KEY* ]]; then
  echo "✓ Authentification : X-N8N-API-KEY"
else
  echo "✓ Authentification : Authorization: Bearer"
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
