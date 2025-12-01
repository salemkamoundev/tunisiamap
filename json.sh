#!/bin/bash

# Vérification de jq
if ! command -v jq &> /dev/null; then
    echo "Erreur : 'jq' n'est pas installé."
    exit 1
fi

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Usage: ./add_gps_by_name.sh data.json"
    exit 1
fi

# 1. Création du fichier de référence temporaire (Gouvernorats + GPS)
# On utilise les données exactes que tu as fournies.
cat <<EOF > /tmp/ref_gps_names.json
[
  { "Nom_Gouvernorat_Ar": "تونس", "gps_lat": "36.8065", "gps_lon": "10.1815" },
  { "Nom_Gouvernorat_Ar": "أريانة", "gps_lat": "36.8665", "gps_lon": "10.1647" },
  { "Nom_Gouvernorat_Ar": "بن عروس", "gps_lat": "36.7531", "gps_lon": "10.2189" },
  { "Nom_Gouvernorat_Ar": "منوبة", "gps_lat": "36.8083", "gps_lon": "10.0972" },
  { "Nom_Gouvernorat_Ar": "نابل", "gps_lat": "36.4561", "gps_lon": "10.7376" },
  { "Nom_Gouvernorat_Ar": "زغوان", "gps_lat": "36.4029", "gps_lon": "10.1429" },
  { "Nom_Gouvernorat_Ar": "بنزرت", "gps_lat": "37.2744", "gps_lon": "9.8739" },
  { "Nom_Gouvernorat_Ar": "باجة", "gps_lat": "36.7256", "gps_lon": "9.1817" },
  { "Nom_Gouvernorat_Ar": "جندوبة", "gps_lat": "36.5011", "gps_lon": "8.7802" },
  { "Nom_Gouvernorat_Ar": "الكاف", "gps_lat": "36.1742", "gps_lon": "8.7049" },
  { "Nom_Gouvernorat_Ar": "سليانة", "gps_lat": "36.0850", "gps_lon": "9.3690" },
  { "Nom_Gouvernorat_Ar": "القيروان", "gps_lat": "35.6781", "gps_lon": "10.0963" },
  { "Nom_Gouvernorat_Ar": "القصرين", "gps_lat": "35.1676", "gps_lon": "8.8308" },
  { "Nom_Gouvernorat_Ar": "سيدي بوزيد", "gps_lat": "35.0382", "gps_lon": "9.4849" },
  { "Nom_Gouvernorat_Ar": "سوسة", "gps_lat": "35.8256", "gps_lon": "10.6084" },
  { "Nom_Gouvernorat_Ar": "المنستير", "gps_lat": "35.7780", "gps_lon": "10.8262" },
  { "Nom_Gouvernorat_Ar": "المهدية", "gps_lat": "35.5047", "gps_lon": "11.0622" },
  { "Nom_Gouvernorat_Ar": "صفاقس", "gps_lat": "34.7406", "gps_lon": "10.7603" },
  { "Nom_Gouvernorat_Ar": "قفصة", "gps_lat": "34.4250", "gps_lon": "8.7842" },
  { "Nom_Gouvernorat_Ar": "توزر", "gps_lat": "33.9197", "gps_lon": "8.1335" },
  { "Nom_Gouvernorat_Ar": "قبلي", "gps_lat": "33.7044", "gps_lon": "8.9690" },
  { "Nom_Gouvernorat_Ar": "قابس", "gps_lat": "33.8815", "gps_lon": "10.0982" },
  { "Nom_Gouvernorat_Ar": "مدنين", "gps_lat": "33.3549", "gps_lon": "10.5055" },
  { "Nom_Gouvernorat_Ar": "تطاوين", "gps_lat": "32.9297", "gps_lon": "10.4518" }
]
EOF

# 2. Jointure des données en utilisant jq
# INDEX(.Nom_Gouvernorat_Ar) : Crée un index basé sur le nom arabe
# $dict[.Nom_Gouvernorat_Ar] : Recherche la correspondance dans cet index

jq --slurpfile refs /tmp/ref_gps_names.json '
  ($refs[0] | INDEX(.Nom_Gouvernorat_Ar)) as $dict
  | map(
      . + {
        gps_lat: ($dict[.Nom_Gouvernorat_Ar].gps_lat // null),
        gps_lon: ($dict[.Nom_Gouvernorat_Ar].gps_lon // null)
      }
    )
' "$INPUT_FILE"

# Nettoyage
rm /tmp/ref_gps_names.json