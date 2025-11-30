#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="merged-src.txt"
SRC_DIR="src"

echo "📝 Concaténation de tous les fichiers du dossier src/ dans $OUTPUT_FILE …"

# Vérifier que src existe
if [ ! -d "$SRC_DIR" ]; then
  echo "❌ Le dossier src/ est introuvable. Lance ce script à la racine du projet Angular."
  exit 1
fi

# Réinitialiser le fichier de sortie
echo "" > "$OUTPUT_FILE"

# Trouver tous les fichiers (TS, HTML, SCSS, CSS, JSON, etc.)
find "$SRC_DIR" -type f | while read -r file; do
  echo "------------------------------" >> "$OUTPUT_FILE"
  echo "📄 Fichier : $file" >> "$OUTPUT_FILE"
  echo "------------------------------" >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "🎉 Terminé !"
echo "Le fichier fusionné est : $OUTPUT_FILE"
