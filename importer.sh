#!/bin/sh
# Importe tous les tableaux de la suite « TeslaMate — à ma sauce » dans Grafana.
#
#   sh importer.sh http://IP-DU-GRAFANA:3000 admin:motdepasse
#   sh importer.sh http://IP-DU-GRAFANA:3000 glsa_xxxxxxxx          (jeton de compte de service)
#   sh importer.sh http://IP-DU-GRAFANA:3000 admin:motdepasse MonUID (si ta source de données n'a pas l'uid « TeslaMate »)
#
# À lancer depuis le dossier qui contient les fichiers .json (par exemple sur ton Unraid).
set -e
URL="${1%/}"
AUTH="$2"
DSUID="${3:-TeslaMate}"
FOLDER_UID="teslamate-a-ma-sauce"
FOLDER_TITLE="TeslaMate — à ma sauce"

if [ -z "$URL" ] || [ -z "$AUTH" ]; then
  echo "Usage : sh importer.sh http://IP:3000 utilisateur:motdepasse|jeton [uid_source_de_données]"
  exit 1
fi
case "$AUTH" in
  *:*) set -- -u "$AUTH" ;;
  *)   set -- -H "Authorization: Bearer $AUTH" ;;
esac

echo "→ Dossier « $FOLDER_TITLE »"
curl -s -o /dev/null "$@" -H "Content-Type: application/json" -X POST "$URL/api/folders" \
  --data "{\"uid\":\"$FOLDER_UID\",\"title\":\"$FOLDER_TITLE\"}" || true

ok=0; ko=0
cd "$(dirname "$0")/dashboards" 2>/dev/null || true
for f in tms-*.json tm-energie-reelle.json; do
  [ -f "$f" ] || continue
  code=$( { printf '{"dashboard":'; sed "s/\"uid\": \"TeslaMate\"/\"uid\": \"$DSUID\"/g" "$f"; \
            printf ',"folderUid":"%s","overwrite":true}' "$FOLDER_UID"; } \
          | curl -s -o /tmp/grafana_import.out -w '%{http_code}' "$@" -H "Content-Type: application/json" \
                 -X POST "$URL/api/dashboards/db" --data-binary @- )
  if [ "$code" = "200" ]; then ok=$((ok+1)); echo "  ✔ $f"; else ko=$((ko+1)); echo "  ✘ $f (HTTP $code) $(cat /tmp/grafana_import.out)"; fi
done
echo "Terminé : $ok importé(s), $ko en erreur."
echo "Ouvre $URL/d/tms-accueil pour commencer."
