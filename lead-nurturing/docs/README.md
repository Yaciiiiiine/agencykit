# Lead Nurturing — Guide d'installation

Séquence email automatisée en 4 étapes (J0, J2, J5, J10) pour agences immobilières, orchestrée via n8n et connectée à Notion.

---

## Prérequis

- [n8n](https://n8n.io) installé (self-hosted ou cloud)
- Un compte SMTP (ex. Brevo, Postmark, Gmail SMTP)
- Un workspace Notion avec une base de données leads
- Accès à votre fichier `config.json`

---

## Étape 1 — Configurer `config.json`

Ouvrez `lead-nurturing/config.json` et renseignez les champs :

```json
{
  "agency_name": "Votre Agence",
  "delay_days": [0, 2, 5, 10],
  "smtp_email": "contact@votre-agence.fr",
  "slack_webhook": "https://hooks.slack.com/services/..."
}
```

> `delay_days` contrôle les délais de la séquence. Modifiez les valeurs selon vos préférences.

---

## Étape 2 — Importer le workflow n8n

1. Connectez-vous à votre instance n8n
2. Cliquez sur **Workflows → Import from file**
3. Sélectionnez `lead-nurturing/workflow/workflow.json`
4. Le workflow s'ouvre avec 4 nœuds préconfigurés

---

## Étape 3 — Configurer les credentials n8n

Dans n8n, ajoutez les credentials suivants :

| Credential | Type | Champs requis |
|---|---|---|
| **SMTP** | Email (SMTP) | Host, port, utilisateur, mot de passe |
| **Notion** | Notion API | Integration token |

Puis dans chaque nœud concerné, sélectionnez le credential correspondant.

---

## Étape 4 — Créer la base Notion

Dans Notion, créez une base de données avec les propriétés suivantes :

| Propriété | Type |
|---|---|
| Nom | Titre |
| Email | Email |
| Statut | Sélection (`Contacté`, `En cours`, `Converti`, `Perdu`) |
| Date de contact | Date |
| Étape | Texte |

Copiez l'ID de la base (dans l'URL Notion) et ajoutez-le comme variable d'environnement `NOTION_DATABASE_ID` dans n8n.

---

## Étape 5 — Personnaliser les emails et activer

1. Ouvrez les fichiers dans `emails/` et remplacez les variables `{{...}}` par vos informations d'agence
2. Dans n8n, activez le workflow avec le bouton **Active**
3. Testez en envoyant une requête POST au webhook :

```bash
curl -X POST https://votre-n8n.fr/webhook/lead-nurturing \
  -H "Content-Type: application/json" \
  -d '{
    "lead_name": "Marie Dupont",
    "lead_email": "marie@exemple.fr",
    "step": "J0",
    "delay_days": 0
  }'
```

La séquence démarre automatiquement. Les leads sont enregistrés dans Notion à chaque étape.

---

## Variables disponibles dans les templates email

| Variable | Description |
|---|---|
| `{{lead_name}}` | Prénom et nom du prospect |
| `{{lead_email}}` | Email du prospect |
| `{{agency_name}}` | Nom de votre agence |
| `{{agency_address}}` | Adresse de l'agence |
| `{{agency_email}}` | Email de contact |
| `{{agency_phone}}` | Téléphone |
| `{{agency_website}}` | Site web |
| `{{booking_url}}` | Lien de prise de rendez-vous |
| `{{unsubscribe_url}}` | Lien de désabonnement |
| `{{agent_name}}` | Nom du conseiller (J10) |

---

## Support

Pour toute question, ouvrez une issue sur le dépôt GitHub.
