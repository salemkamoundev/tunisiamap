import { Component } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
// On utilise LeafletModule. Si cela échoue, vérifiez votre package.json.
import { LeafletModule } from '@bluehalo/ngx-leaflet'; 
// import { LeafletModule } from 'ngx-leaflet'; // Alternative si bluehalo n'est pas installé

import * as L from 'leaflet';
import 'leaflet.markercluster'; 
import { MapDataService } from './services/map-data.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LeafletModule, HttpClientModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
  providers: [MapDataService]
})
export class AppComponent {
  map!: L.Map;
  currentLayer: any = null; // Stocke le calque actif pour pouvoir le supprimer

  // Liste des catégories en dur pour garantir l'affichage
  categories: string[] = [
    'Lycée',
    'Maison des Jeunes',
    'Poste',
    'Ministère',
    'Budget 2021'
  ];

  // Options de base de la carte (Vue Tunisie)
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
    // Charge les données classiques au démarrage
    this.loadStandardData('Toutes');
  }

  // Changement de catégorie via le Select
  onCategoryChange(event: any) {
    const selectedCat = event.target.value;
    
    // 1. Nettoyer la carte
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
      this.currentLayer = null;
    }

    // 2. Choisir la logique de chargement
    if (selectedCat === 'Budget 2021') {
      this.loadBudgetData();
    } else {
      this.loadStandardData(selectedCat);
    }
  }

  // --- LOGIQUE SPÉCIALE BUDGET 2021 ---
  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        // Création du groupe de cluster
        const budgetCluster = L.markerClusterGroup({
          maxClusterRadius: 60,
          // Fonction personnalisée pour l'icône du cluster
          iconCreateFunction: (cluster) => {
            const markers = cluster.getAllChildMarkers();
            let totalPrevision = 0;

            // On additionne la propriété 'previsionAmount' stockée dans chaque marker
            markers.forEach((marker: any) => {
              if (marker.options.previsionAmount) {
                totalPrevision += marker.options.previsionAmount;
              }
            });

            // Formatage Monétaire (TND)
            const formattedSum = new Intl.NumberFormat('fr-TN', { 
              style: 'currency', 
              currency: 'TND', 
              maximumFractionDigits: 0 
            }).format(totalPrevision);

            return L.divIcon({
              html: `<div class="budget-cluster-icon">
                       <span>${formattedSum}</span>
                       <small>(${markers.length} mun.)</small>
                     </div>`,
              className: 'budget-cluster',
              iconSize: L.point(90, 90)
            });
          }
        });

        // Création des marqueurs individuels
        data.forEach(item => {
          const lat = parseFloat(item.lat);
          const lng = parseFloat(item.lng);

          // NETTOYAGE: 'depenses_prevision' ("84000" ou "84 000") -> Float
          const rawPrevision = item.depenses_prevision ? String(item.depenses_prevision) : '0';
          // Enlève les espaces, remplace virgule par point
          const valPrevision = parseFloat(rawPrevision.replace(/\s/g, '').replace(',', '.'));

          if (!isNaN(lat) && !isNaN(lng)) {
            const marker = L.marker([lat, lng], {
              icon: L.icon({
                iconUrl: 'assets/marker-icon.png',
                shadowUrl: 'assets/marker-shadow.png',
                iconSize: [25, 41],
                iconAnchor: [12, 41],
                popupAnchor: [1, -34]
              })
            });

            // IMPORTANT : On attache la valeur 'prevision' au marker pour le cluster
            (marker.options as any)['previsionAmount'] = valPrevision;

            // Popup : Affiche TOUS les champs
            marker.bindPopup(this.generateFullPopup(item));

            budgetCluster.addLayer(marker);
          }
        });

        this.currentLayer = budgetCluster;
        this.map.addLayer(this.currentLayer);
        
        // Zoom automatique sur les données
        if (data.length > 0) {
            const bounds = budgetCluster.getBounds();
            if (bounds.isValid()) this.map.fitBounds(bounds);
        }
      },
      error: (err) => console.error('Erreur chargement budget:', err)
    });
  }

  // --- LOGIQUE STANDARD (Lycées, Postes...) ---
  loadStandardData(category: string) {
    this.mapService.getLocations().subscribe({
      next: (locations) => {
        const filtered = category === 'Toutes' 
          ? null 
          : locations.filter(l => l.categorie === category);

        const layerGroup = L.layerGroup();

        if(filtered )filtered.forEach(loc => {
          const marker = L.marker([loc.lat, loc.lng], {
            icon: L.icon({
              iconUrl: 'assets/marker-icon.png',
              shadowUrl: 'assets/marker-shadow.png',
              iconSize: [25, 41],
              iconAnchor: [12, 41],
              popupAnchor: [1, -34]
            })
          });
          marker.bindPopup(`<b>${loc.nom}</b><br>${loc.categorie}`);
          layerGroup.addLayer(marker);
        });

        this.currentLayer = layerGroup;
        this.map.addLayer(this.currentLayer);
      }
    });
  }

  // Génère un tableau HTML avec TOUTES les clés du JSON
  generateFullPopup(data: any): string {
    let rows = '';
    // On parcourt toutes les clés de l'objet
    for (const key in data) {
      if (data.hasOwnProperty(key)) {
        // On exclut lat/lng car c'est redondant, mais on garde tout le reste
        if (key !== 'lat' && key !== 'lng') {
           rows += `
            <tr>
              <td style="font-weight:bold; color:#555; padding:4px; border-bottom:1px solid #eee;">${key}</td>
              <td style="padding:4px; border-bottom:1px solid #eee;">${data[key]}</td>
            </tr>`;
        }
      }
    }

    return `
      <div style="max-height: 300px; overflow-y: auto; font-family: sans-serif; min-width: 250px;">
        <h3 style="margin-top:0; color:#28a745; border-bottom: 2px solid #28a745;">Détails Budget</h3>
        <table style="width:100%; border-collapse: collapse; font-size: 12px;">
          <tbody>${rows}</tbody>
        </table>
      </div>
    `;
  }
}
