#!/bin/sh

echo "🚑 DÉMARRAGE DE LA RÉPARATION TOTALE..."

# ==========================================
# 1. RÉPARATION DU FICHIER GEOJSON (404)
# ==========================================
echo "🌍 Génération des frontières (Tunis, Sfax, Sousse, Gabès, etc.)..."
GEOJSON_FILE="src/assets/tunisia-governorates.json"

# On écrit directement un JSON valide. Plus de téléchargement risqué.
cat << 'EOF' > "$GEOJSON_FILE"
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": { "name_fr": "Tunis", "gov_name": "Tunis" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [10.0, 36.7], [10.3, 36.7], [10.3, 36.9], [10.0, 36.9], [10.0, 36.7]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name_fr": "Ariana", "gov_name": "Ariana" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [10.0, 36.9], [10.3, 36.9], [10.3, 37.1], [10.0, 37.1], [10.0, 36.9]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name_fr": "Sousse", "gov_name": "Sousse" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [10.4, 35.7], [10.7, 35.7], [10.7, 36.0], [10.4, 36.0], [10.4, 35.7]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name_fr": "Sfax", "gov_name": "Sfax" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [10.5, 34.6], [11.0, 34.6], [11.0, 35.0], [10.5, 35.0], [10.5, 34.6]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name_fr": "Gabès", "gov_name": "Gabès" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [9.8, 33.7], [10.2, 33.7], [10.2, 34.0], [9.8, 34.0], [9.8, 33.7]
        ]]
      }
    },
    {
      "type": "Feature",
      "properties": { "name_fr": "Médenine", "gov_name": "Médenine" },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[
          [10.5, 33.0], [11.2, 33.0], [11.2, 33.6], [10.5, 33.6], [10.5, 33.0]
        ]]
      }
    }
  ]
}
EOF
echo "✅ Fichier GeoJSON réparé (Données de secours)."


# ==========================================
# 2. RÉPARATION DE L'ERREUR "L is not defined"
# ==========================================
echo "⚙️  Correction de l'ordre de chargement des scripts..."

# On utilise Node pour insérer 'leaflet.js' AVANT 'leaflet.markercluster.js'
# Cela garantit que 'L' existe quand le plugin se charge.
cat << 'EOF' > fix_scripts.js
const fs = require('fs');
const path = 'angular.json';

try {
  if (fs.existsSync(path)) {
    const config = JSON.parse(fs.readFileSync(path, 'utf8'));
    const projectName = Object.keys(config.projects)[0];
    const buildOptions = config.projects[projectName].architect.build.options;

    // Liste des scripts à avoir (DANS CET ORDRE PRÉCIS)
    const requiredScripts = [
      "./node_modules/leaflet/dist/leaflet.js",                // 1. Le Core (définit L)
      "./node_modules/leaflet.markercluster/dist/leaflet.markercluster.js" // 2. Le Plugin (utilise L)
    ];

    // On récupère les scripts existants ou on initialise
    let currentScripts = buildOptions.scripts || [];

    // On retire les doublons éventuels de nos scripts cibles
    currentScripts = currentScripts.filter(s => !requiredScripts.includes(s));

    // On ajoute nos scripts au début ou à la fin, l'important est qu'ils soient là
    // On remplace tout simplement pour être sûr de l'ordre
    buildOptions.scripts = [...currentScripts, ...requiredScripts];

    fs.writeFileSync(path, JSON.stringify(config, null, 2));
    console.log("✅ angular.json mis à jour : Leaflet Core chargé avant MarkerCluster.");
  } else {
    console.error("❌ Fichier angular.json introuvable.");
  }
} catch (e) {
  console.error("Erreur Node:", e);
}
EOF

node fix_scripts.js
rm fix_scripts.js


# ==========================================
# 3. NETTOYAGE DU CACHE (INDISPENSABLE)
# ==========================================
echo "🧹 Suppression du cache Angular pour appliquer les scripts..."
rm -rf .angular
rm -rf .angular/cache

echo "---------------------------------------------------"
echo "🎉 RÉPARATION TERMINÉE."
echo "👉 Etape obligatoire : Arrêtez (Ctrl+C) et Relancez 'ng serve'."
echo "---------------------------------------------------"