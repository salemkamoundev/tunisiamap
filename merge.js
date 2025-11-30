const fs = require('fs');
const path = require('path');

// 1. Configuration des fichiers
const files = [
  // Cas avec colonnes identifiées
  { name: 'ecole.json', category: 'École', type: 'explicit' },
  
  // Cas sans nom de colonnes (index 0,1,2...)
  { name: 'lycées.json', category: 'Lycée', type: 'scan' },
  { name: 'postes.json', category: 'Poste', type: 'scan' },
  { name: 'ministere.json', category: 'Ministère', type: 'scan' },
  { name: 'maisonsJeunes.json', category: 'Maison des Jeunes', type: 'scan' },
  // { name: 'hopitaux.json', category: 'Hôpital', type: 'scan' } 
];

let allLocations = [];

console.log("🚀 Démarrage de la fusion (Correction Virgules & Format)...\n");

files.forEach(file => {
  // Gestion flexible du nom de fichier (singulier/pluriel/accents)
  let filePath = path.join(__dirname, file.name);
  if (!fs.existsSync(filePath)) {
    const alts = [
        file.name.replace('é','e'), 
        file.name.replace('s.json','.json'), 
        'lycees.json', 
        'ministeres.json'
    ];
    for(const alt of alts) {
      if(fs.existsSync(path.join(__dirname, alt))) {
        filePath = path.join(__dirname, alt);
        break;
      }
    }
  }

  if (fs.existsSync(filePath)) {
    try {
      const raw = fs.readFileSync(filePath, 'utf8');
      let data = JSON.parse(raw);
      
      // Aplatir les structures { data: [...] } ou { results: [...] }
      const items = Array.isArray(data) ? data : (data.data || data.results || Object.values(data));

      let count = 0;

      items.forEach(item => {
        let nom = null;
        let lat = null;
        let lng = null;

        // --- STRATÉGIE 1 : EXPLICITE (ecole.json) ---
        if (file.type === 'explicit') {
          // On force la conversion en string puis le remplacement virgule->point
          const rawLat = String(item['Latitude initiale'] || '').replace(',', '.');
          const rawLng = String(item['Longitude initiale'] || '').replace(',', '.');
          
          if (rawLat && rawLng) {
            lat = parseFloat(rawLat);
            lng = parseFloat(rawLng);
            nom = item['nom_etablissement'] || item['nom_etablissement_ar'];
          }
        }
        
        // --- STRATÉGIE 2 : SCANNER ROBUSTE (fichiers indexés) ---
        else if (file.type === 'scan') {
          const values = Object.values(item);
          let potentialName = "";

          for (const v of values) {
            if (!v) continue;

            const valStr = String(v).trim();
            
            // 1. Tenter de parser un nombre (gestion virgule)
            // On remplace la virgule par un point pour le format JS
            const numStr = valStr.replace(',', '.');
            const num = parseFloat(numStr);

            // Est-ce une coordonnée valide ?
            if (!isNaN(num)) {
              // Plage Latitude Tunisie : ~30 à ~38
              if (num > 30 && num < 38) {
                lat = num; 
              } 
              // Plage Longitude Tunisie : ~7 à ~12 (élargi à 13 au cas où)
              else if (num > 7 && num < 13) {
                lng = num;
              }
            }

            // 2. Chercher le meilleur nom (le texte le plus long qui n'est pas un nombre)
            // Cela évite de prendre "Tunis" (Gouvernorat) au lieu de "Lycée Pilote..."
            if (isNaN(num) && valStr.length > potentialName.length) {
                // On évite les URL ou les chaînes trop bizarres si nécessaire
                potentialName = valStr;
            }
          }
          nom = potentialName;
        }

        // --- VALIDATION FINALE ---
        // On n'ajoute que si on a tout ce qu'il faut
        if (lat && lng && nom) {
          allLocations.push({
            nom: nom.replace(/\r?\n|\r/g, " ").trim(), // Nettoyage sauts de ligne
            categorie: file.category,
            lat: lat,
            lng: lng
          });
          count++;
        }
      });

      console.log(`✅ ${file.name} : ${count} lieux ajoutés.`);

    } catch (e) {
      console.log(`❌ Erreur lecture ${file.name}: ${e.message}`);
    }
  } else {
    console.log(`⚠️  Fichier introuvable : ${file.name}`);
  }
});

// Écriture du résultat
const outputPath = path.join(__dirname, 'src', 'assets', 'all_locations.json');

// Création dossier si besoin
const dir = path.dirname(outputPath);
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

fs.writeFileSync(outputPath, JSON.stringify(allLocations, null, 2));

console.log("\n---------------------------------------------------");
if (allLocations.length > 0) {
  console.log(`🎉 SUCCÈS TOTAL : ${allLocations.length} lieux enregistrés.`);
  console.log(`📂 Fichier : ${outputPath}`);
} else {
  console.log("❌ ZÉRO RÉSULTAT. Vérifiez que vos fichiers JSON contiennent bien des nombres pour les coordonnées.");
}