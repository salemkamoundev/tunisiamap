#!/bin/bash

# 1. Création du fichier source temporaire avec tes données
# (On colle ton JSON ici pour l'exemple, mais tu peux aussi lire un fichier externe)

# 2. Traitement avec jq
# On injecte une map des coordonnées GPS des gouvernorats
# On extrait le tableau "universites"
# On ajoute les champs pour chaque entrée

jq '
  # Dictionnaire des coordonnées approximatives des Gouvernorats
  {
    "Tunis":     {lat: 36.8065, lng: 10.1815},
    "Ariana":    {lat: 36.8665, lng: 10.1647},
    "Ben Arous": {lat: 36.7531, lng: 10.2189},
    "Manouba":   {lat: 36.8083, lng: 10.0863},
    "Nabeul":    {lat: 36.4561, lng: 10.7376},
    "Zaghouan":  {lat: 36.4029, lng: 10.1429},
    "Bizerte":   {lat: 37.2744, lng: 9.8739},
    "Béja":      {lat: 36.7256, lng: 9.1817},
    "Jendouba":  {lat: 36.5011, lng: 8.7802},
    "Le Kef":    {lat: 36.1680, lng: 8.7096},
    "Siliana":   {lat: 36.0840, lng: 9.3708},
    "Kairouan":  {lat: 35.6781, lng: 10.0963},
    "Kasserine": {lat: 35.1676, lng: 8.8365},
    "Sidi Bouzid": {lat: 35.0382, lng: 9.4849},
    "Sousse":    {lat: 35.8256, lng: 10.6084},
    "Monastir":  {lat: 35.7770, lng: 10.8261},
    "Mahdia":    {lat: 35.5047, lng: 11.0622},
    "Sfax":      {lat: 34.7406, lng: 10.7603},
    "Gabès":     {lat: 33.8815, lng: 10.0982},
    "Médenine":  {lat: 33.3549, lng: 10.5055},
    "Tataouine": {lat: 32.9297, lng: 10.4518},
    "Gafsa":     {lat: 34.4250, lng: 8.7842},
    "Tozeur":    {lat: 33.9197, lng: 8.1335},
    "Kebili":    {lat: 33.7044, lng: 8.9690}
  } as $coords
  
  | map(
      . + {
        "categorie": "Université",
        "lat": ($coords[.gouvernorat].lat // null),
        "lng": ($coords[.gouvernorat].lng // null)
      }
    )
' ../universités.json > resultat_universites.json

# 3. Affichage du résultat
cat resultat_universites.json