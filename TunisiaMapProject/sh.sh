#!/bin/bash

FILE="src/app/app.component.ts"

echo "=== Début du correctif de clustering pour $FILE ==="

# 1. Sauvegarde du fichier original
cp "$FILE" "$FILE.bak"
echo "✅ Sauvegarde créée : $FILE.bak"

# 2. Correction de la map pour stocker aussi les noms (Gouvernorat et Municipalité)
# On remplace l'objet stocké {lat, lng} par {lat, lng, govName, munName}
sed -i 's/coordsMap.set(b.Code_Municipalite_INS, { lat: b.lat, lng: b.lng });/coordsMap.set(b.Code_Municipalite_INS, { lat: b.lat, lng: b.lng, govName: b.Nom_Gouvernorat_Ar, munName: b.Nom_Municipalite_Ar });/' "$FILE"

# 3. Utilisation du nom du gouvernorat provenant du Budget (coords.govName) en priorité
# Si coords.govName existe, on l'utilise, sinon on garde FIELD3
sed -i 's/Nom_Gouvernorat_Ar: r.FIELD3,/Nom_Gouvernorat_Ar: coords.govName || r.FIELD3,/' "$FILE"

# 4. Utilisation du nom de la municipalité provenant du Budget (coords.munName) en priorité
# Pour garantir la cohérence d'affichage
sed -i 's/Nom_Municipalite_Ar: r.FIELD2,/Nom_Municipalite_Ar: coords.munName || r.FIELD2,/' "$FILE"

echo "✅ Correctif appliqué avec succès."
echo "=== Redémarrez 'ng serve' pour voir les clusters par gouvernorat ==="