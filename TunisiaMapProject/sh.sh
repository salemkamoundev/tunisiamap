#!/bin/bash

echo "🚑 Réparation de l'affichage de toutes les catégories..."

# 1. Réécriture de src/app/app.ts avec la logique corrigée
echo "💻 Mise à jour de src/app/app.ts..."
cat <<EOF > src/app/app.ts
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { LeafletModule } from '@bluehalo/ngx-leaflet'; 

import * as L from 'leaflet';
import 'leaflet.markercluster'; 
import { MapDataService } from './services/map-data.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LeafletModule, HttpClientModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css'],
  providers: [MapDataService]
})
export class App {
  map!: L.Map;
  currentLayer: any = null;

  categories: string[] = [
    'Toutes',
    'Lycée',
    'Maison des Jeunes',
    'Poste',
    'Ministère',
    'Budget 2021'
  ];

  options = {
    layers: [
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '© OpenStreetMap contributors'
      })
    ],
    zoom: 7,
    center: L.latLng(33.8869, 9.5375)
  };

  constructor(private mapService: MapDataService) {}

  onMapReady(map: L.Map) {
    this.map = map;
    // Charge 'Toutes' au démarrage
    this.loadStandardData('Toutes');
  }

  onCategoryChange(event: any) {
    const selectedCat = event.target.value;
    
    // Nettoyage du calque précédent
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
      this.currentLayer = null;
    }

    if (selectedCat === 'Budget 2021') {
      this.loadBudgetData();
    } else {
      this.loadStandardData(selectedCat);
    }
  }

  // --- 1. LOGIQUE SPÉCIALE BUDGET 2021 (Somme + Popup Complet) ---
  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        const budgetCluster = L.markerClusterGroup({
          maxClusterRadius: 60,
          // Icône personnalisée avec la SOMME
          iconCreateFunction: (cluster) => {
            const markers = cluster.getAllChildMarkers();
            let totalPrevision = 0;

            markers.forEach((marker: any) => {
              if (marker.options.previsionAmount) {
                totalPrevision += marker.options.previsionAmount;
              }
            });

            const formattedSum = new Intl.NumberFormat('fr-TN', { 
              style: 'currency', currency: 'TND', maximumFractionDigits: 0 
            }).format(totalPrevision);

            return L.divIcon({
              html: \`<div class="budget-cluster-icon">
                       <span>\${formattedSum}</span>
                       <small>(\${markers.length} mun.)</small>
                     </div>\`,
              className: 'budget-cluster',
              iconSize: L.point(90, 90)
            });
          }
        });

        data.forEach(item => {
          const lat = parseFloat(item.lat);
          const lng = parseFloat(item.lng);
          const rawPrevision = item.depenses_prevision ? String(item.depenses_prevision) : '0';
          const valPrevision = parseFloat(rawPrevision.replace(/\s/g, '').replace(',', '.'));

          if (!isNaN(lat) && !isNaN(lng)) {
            const marker = L.marker([lat, lng], {
              icon: L.icon({
                iconUrl: 'assets/marker-icon.png',
                shadowUrl: 'assets/marker-shadow.png',
                iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34]
              })
            });
            (marker.options as any)['previsionAmount'] = valPrevision;
            marker.bindPopup(this.generateFullPopup(item));
            budgetCluster.addLayer(marker);
          }
        });

        this.currentLayer = budgetCluster;
        this.map.addLayer(this.currentLayer);
        
        if (data.length > 0) {
            const bounds = budgetCluster.getBounds();
            if (bounds.isValid()) this.map.fitBounds(bounds);
        }
      },
      error: (err) => console.error('Erreur Budget:', err)
    });
  }

  // --- 2. LOGIQUE STANDARD (Clustering par défaut) ---
  loadStandardData(category: string) {
    this.mapService.getLocations().subscribe({
      next: (locations) => {
        // CORRECTION MAJEURE ICI : Si 'Toutes', on prend tout le tableau locations
        const filtered = category === 'Toutes' 
          ? locations 
          : locations.filter(l => l.categorie === category);

        // On utilise MarkerClusterGroup pour avoir le regroupement standard (bleu/jaune/rouge)
        const standardCluster = L.markerClusterGroup();

        filtered.forEach(loc => {
          const marker = L.marker([loc.lat, loc.lng], {
            icon: L.icon({
              iconUrl: 'assets/marker-icon.png',
              shadowUrl: 'assets/marker-shadow.png',
              iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34]
            })
          });
          marker.bindPopup(\`<b>\${loc.nom}</b><br>\${loc.categorie}\`);
          standardCluster.addLayer(marker);
        });

        this.currentLayer = standardCluster;
        this.map.addLayer(this.currentLayer);

        // Zoom automatique pour voir les points
        if (filtered.length > 0) {
            const bounds = standardCluster.getBounds();
            if (bounds.isValid()) this.map.fitBounds(bounds);
        }
      },
      error: (err) => console.error('Erreur Standard:', err)
    });
  }

  generateFullPopup(data: any): string {
    let rows = '';
    for (const key in data) {
      if (data.hasOwnProperty(key) && key !== 'lat' && key !== 'lng') {
         rows += \`
          <tr>
            <td style="font-weight:bold; color:#555; padding:3px; border-bottom:1px solid #eee;">\${key}</td>
            <td style="padding:3px; border-bottom:1px solid #eee;">\${data[key]}</td>
          </tr>\`;
      }
    }
    return \`<div style="max-height:300px; overflow-y:auto; min-width:250px;">
              <h3 style="margin-top:0; color:#28a745; font-size:14px;">Détails</h3>
              <table style="width:100%; border-collapse:collapse; font-size:12px;"><tbody>\${rows}</tbody></table>
            </div>\`;
  }
}
EOF

# 2. Assurance du CSS MarkerCluster (Au cas où)
echo "🎨 Vérification des styles..."
if ! grep -q "MarkerCluster.css" src/styles.css; then
  cat <<EOF >> src/styles.css
@import "leaflet.markercluster/dist/MarkerCluster.css";
@import "leaflet.markercluster/dist/MarkerCluster.Default.css";
EOF
fi

echo "✅ Correction appliquée. Relancez 'ng serve'."