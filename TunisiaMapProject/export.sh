#!/bin/sh

# Nom du fichier de sortie
OUTPUT_FILE="merged_angular_src.txt"

# Dossier source
SOURCE_DIR="src/app"

# Extensions à inclure (fichiers de code et de configuration)
INCLUDED_EXTENSIONS="html|ts|js|css|scss|json|md|txt"

# Dossiers et fichiers à exclure (binaires, caches, grandes données)
EXCLUDED_PATTERNS=("node_modules" ".angular" ".git" ".DS_Store" "merged_angular_src.txt" "merged-src.txt" "png$" "jpg$" "ico$" "eot$" "ttf$" "woff$")

# --- Début du script ---

echo "🔄 Concaténation de tous les fichiers de code dans $SOURCE_DIR/ vers $OUTPUT_FILE..."

# Supprimer le fichier de sortie existant s'il y a lieu
rm -f "$OUTPUT_FILE"

# Commencer par le chemin racine du dossier src
find "$SOURCE_DIR" -type f | while IFS= read -r FILE; do
    
    FILENAME=$(basename "$FILE")
    
    # 1. Vérification de l'extension
    if ! echo "$FILENAME" | grep -E "\.($INCLUDED_EXTENSIONS)$" > /dev/null; then
        # On ignore si l'extension n'est pas dans la liste
        continue
    fi

    # 2. Vérification des dossiers et fichiers à exclure
    EXCLUDE=0
    for PATTERN in "${EXCLUDED_PATTERNS[@]}"; do
        if echo "$FILE" | grep -E "$PATTERN" > /dev/null; then
            EXCLUDE=1
            break
        fi
    done
    
    if [ "$EXCLUDE" -eq 1 ]; then
        continue
    fi
    
    # --- Traitement du fichier ---
    
    echo "------------------------------" >> "$OUTPUT_FILE"
    echo "📄 Fichier : $FILE" >> "$OUTPUT_FILE"
    echo "------------------------------" >> "$OUTPUT_FILE"
    
    # Ajouter le contenu du fichier
    cat "$FILE" >> "$OUTPUT_FILE"
    
    # Ajouter une ligne vide pour la séparation
    echo "" >> "$OUTPUT_FILE"
    
    echo "✅ Ajouté : $FILE"

done

echo "---------------------------------------------------"
echo "🎉 Concaténation terminée. Le résultat est dans $OUTPUT_FILE."
echo "---------------------------------------------------"