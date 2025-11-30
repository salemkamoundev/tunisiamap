#!/bin/bash

echo "🚀 Démarrage de la configuration du Clustering..."

# 1. Installation des dépendances nécessaires
echo "📦 Installation de leaflet.markercluster..."
npm install leaflet.markercluster --force
npm install --save-dev @types/leaflet.markercluster --force

# 2. Mise à jour du fichier src/app/app.ts
# On configure le cluster pour qu'il soit interactif et stylisé
echo "📝 Mise à jour de src/app/app.ts..."
cat > src/app/app.ts <<EOF
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { MapDataService, Location } from './services/map-data.service';
import * as L from 'leaflet';
import { forkJoin } from 'rxjs';

// Import important pour que le plugin s'attache à L
import 'leaflet.markercluster';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LeafletModule], 
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit {
  allLocations: Location[] = [];
  categories: string[] = [];
  selectedCategory: string = '';

  // Configuration de la carte
  options = {
    layers: [
      L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors &copy; CARTO'
      })
    ],
    zoom: 7,
    center: L.latLng(34.0, 9.0)
  };

  // On utilise 'any' pour contourner le typage strict de MarkerClusterGroup qui peut parfois poser problème
  markerClusterGroup: any; 
  geoJsonLayer: L.GeoJSON | undefined;
  layers: L.Layer[] = [];

  constructor(private mapDataService: MapDataService) {}

  ngOnInit() {
    // Fix des icônes par défaut de Leaflet qui disparaissent dans Angular
    this.fixLeafletIcons();

    forkJoin({
      locations: this.mapDataService.getLocations(),
      geoJson: this.mapDataService.getGovernorates()
    }).subscribe({
      next: (data) => {
        // 1. Gestion des lieux
        if (data.locations && data.locations.length > 0) {
          this.allLocations = data.locations;
          // Extraction des catégories uniques
          const uniqueCats = new Set(this.allLocations.map(l => l.categorie).filter(c => c));
          this.categories = Array.from(uniqueCats).sort();
          
          // Initialisation des clusters avec tous les points au début
          this.initMarkers(this.allLocations);
        }

        // 2. Gestion des frontières (Gouvernorats)
        if (data.geoJson) {
          this.initGeoJsonLayer(data.geoJson);
        }
      },
      error: (err) => console.error('Erreur chargement:', err)
    });
  }

  fixLeafletIcons() {
    const iconRetinaUrl = 'assets/marker-icon-2x.png';
    const iconUrl = 'assets/marker-icon.png';
    const shadowUrl = 'assets/marker-shadow.png';
    const iconDefault = L.icon({
      iconRetinaUrl,
      iconUrl,
      shadowUrl,
      iconSize: [25, 41],
      iconAnchor: [12, 41],
      popupAnchor: [1, -34],
      tooltipAnchor: [16, -28],
      shadowSize: [41, 41]
    });
    L.Marker.prototype.options.icon = iconDefault;
  }

  initGeoJsonLayer(geoJsonData: any) {
    this.geoJsonLayer = L.geoJSON(geoJsonData, {
      style: (feature) => ({
        color: '#444', weight: 1, opacity: 0.5, fillColor: 'transparent', fillOpacity: 0
      }),
      onEachFeature: (feature, layer) => {
        layer.on('mouseover', (e) => { 
            const l = e.target; 
            l.setStyle({ weight: 3, color: '#FF1493', opacity: 0.8 }); 
        });
        layer.on('mouseout', (e) => { 
            const l = e.target; 
            this.geoJsonLayer?.resetStyle(l); 
        });
      }
    });
    this.layers.push(this.geoJsonLayer);
  }

  onCategoryChange(event: Event) {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedCategory = selectElement.value;
    
    if (this.selectedCategory) {
      const filtered = this.allLocations.filter(l => l.categorie === this.selectedCategory);
      this.initMarkers(filtered);
    } else {
      this.initMarkers(this.allLocations);
    }
  }

  initMarkers(locations: Location[]) {
    // Suppression de l'ancien groupe s'il existe
    if (this.markerClusterGroup) {
      const index = this.layers.indexOf(this.markerClusterGroup);
      if (index > -1) {
        this.layers.splice(index, 1);
        // Force update par réassignation
        this.layers = [...this.layers];
      }
    }

    // Création du groupe de cluster avec style personnalisé
    this.markerClusterGroup = (L as any).markerClusterGroup({
      removeOutsideVisibleBounds: true,
      animate: true,
      // Fonction pour créer l'icône du cluster (le rond coloré)
      iconCreateFunction: function (cluster: any) {
        const childCount = cluster.getChildCount();
        let c = ' marker-cluster-';
        if (childCount < 10) {
          c += 'small';
        } else if (childCount < 100) {
          c += 'medium';
        } else {
          c += 'large';
        }

        return new L.DivIcon({ 
          html: '<div><span>' + childCount + '</span></div>', 
          className: 'custom-cluster' + c, 
          iconSize: new L.Point(40, 40) 
        });
      }
    });

    // Création des marqueurs
    const markers = locations.map(loc => {
      return L.marker([loc.lat, loc.lng], { title: loc.nom })
        .bindPopup(\`
          <div style="font-family:sans-serif; text-align:center;">
            <h4 style="margin:0; color:#FF1493;">\${loc.nom}</h4>
            <span style="background:#eee; padding:2px 6px; border-radius:4px; font-size:12px;">\${loc.categorie}</span>
          </div>
        \`);
    });

    // Ajout des marqueurs au groupe
    this.markerClusterGroup.addLayers(markers);
    
    // Ajout du groupe à la carte
    this.layers.push(this.markerClusterGroup);
  }

  onMapReady(map: L.Map) {
    // Ajustement automatique de la vue si nécessaire
  }
}
EOF

# 3. Mise à jour du CSS pour rendre les clusters "Jolis"
echo "🎨 Mise à jour de src/app/app.css pour le style des clusters..."
cat > src/app/app.css <<EOF
/* Conteneur principal */
.map-wrapper {
  position: relative;
  height: 100vh;
  width: 100%;
}

.map-container {
  height: 100%;
  width: 100%;
  z-index: 1;
}

/* Filtres */
.filter-controls {
  position: absolute;
  top: 20px;
  right: 20px;
  z-index: 1000;
  background-color: rgba(255, 255, 255, 0.95);
  padding: 15px;
  border-radius: 12px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-width: 220px;
  backdrop-filter: blur(5px);
}

.filter-controls label {
  font-weight: 600;
  color: #333;
  font-size: 0.9rem;
}

.category-select {
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  outline: none;
  transition: border-color 0.3s;
}
.category-select:focus {
  border-color: #FF1493;
}

/* --- STYLES DES CLUSTERS PERSONNALISÉS --- */

/* Base du cercle */
.custom-cluster {
  background-clip: padding-box;
  border-radius: 50%;
}

.custom-cluster div {
  width: 36px;
  height: 36px;
  margin-left: 2px;
  margin-top: 2px;
  text-align: center;
  border-radius: 50%;
  font-weight: bold;
  color: white;
  font-family: sans-serif;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 10px rgba(0,0,0,0.3);
  border: 2px solid rgba(255,255,255,0.5);
  transition: transform 0.2s ease;
}

.custom-cluster div:hover {
  transform: scale(1.1);
}

/* Petit Cluster (< 10) - Rose léger */
.custom-cluster-small div {
  background: linear-gradient(135deg, #ff80bf 0%, #ff1493 100%);
}

/* Moyen Cluster (< 100) - Rose Vif / Violet */
.custom-cluster-medium div {
  background: linear-gradient(135deg, #ff1493 0%, #9400d3 100%);
  width: 42px; /* Un peu plus grand */
  height: 42px;
  margin-left: -1px;
  margin-top: -1px;
  font-size: 14px;
}

/* Grand Cluster (> 100) - Violet Sombre / Bleu Nuit */
.custom-cluster-large div {
  background: linear-gradient(135deg, #9400d3 0%, #4b0082 100%);
  width: 50px;
  height: 50px;
  margin-left: -5px;
  margin-top: -5px;
  font-size: 16px;
}

/* Animation du chiffre */
.custom-cluster span {
  line-height: 1;
}
EOF

# 4. Vérification des styles globaux (Leaflet CSS)
echo "🎨 Vérification de src/styles.css..."
cat > src/styles.css <<EOF
/* Import des styles de base Leaflet */
@import "leaflet/dist/leaflet.css";

/* Import des styles pour les clusters (Nécessaire pour la logique, même si on style par dessus) */
@import "leaflet.markercluster/dist/MarkerCluster.css";
@import "leaflet.markercluster/dist/MarkerCluster.Default.css";

html, body { 
    height: 100%; 
    margin: 0; 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}
EOF

echo "✅ Terminé ! Lancez 'ng serve' pour voir votre carte avec clustering."