#!/bin/bash

echo "🚀 Mise à jour : Catégories + Affichage des noms de zones dans les clusters..."

# 1. Mise à jour de src/app/app.ts
echo "💻 Réécriture de src/app/app.ts..."
cat <<EOF > src/app/app.ts
import { Component } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms'; 
import { LeafletModule } from '@bluehalo/ngx-leaflet'; 

import * as L from 'leaflet';
import 'leaflet.markercluster'; 
import { MapDataService } from './services/map-data.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LeafletModule, HttpClientModule, FormsModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css'],
  providers: [MapDataService]
})
export class App {
  map!: L.Map;
  currentLayer: any = null;

  // --- NOUVELLE LISTE DES CATÉGORIES ---
  categories: string[] = [ 
    'Stade', 
    'Lycée', 
    'Maison des Jeunes', 
    'Poste', 
    'Université', 
    'École', 
    'Budget 2021' 
  ];

  // Variables Filtres
  isBudgetActive: boolean = false;
  filtersVisible: boolean = true;
  allBudgetData: any[] = [];
  filteredBudgetData: any[] = [];
  listGouvernorats: string[] = [];
  listMunicipalites: string[] = [];
  selectedGov: string = '';
  selectedMun: string = '';

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
    // Charge la première catégorie par défaut (Stade) ou 'Toutes' si vous préférez
    // Ici on ne charge rien au début ou une catégorie par défaut
    // this.loadStandardData('Stade'); 
  }

  onCategoryChange(event: any) {
    const selectedCat = event.target.value;
    
    this.isBudgetActive = (selectedCat === 'Budget 2021');
    
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
      this.currentLayer = null;
    }

    if (this.isBudgetActive) {
      this.loadBudgetData();
    } else {
      this.loadStandardData(selectedCat);
    }
  }

  // --- LOGIQUE BUDGET 2021 AVEC NOMS GÉOGRAPHIQUES ---
  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        this.allBudgetData = data;
        this.extractFilterOptions();
        this.applyBudgetFilters(); // Lance l'affichage
      },
      error: (err) => console.error('Erreur Budget:', err)
    });
  }

  extractFilterOptions() {
    const govs = this.allBudgetData.map(item => item.Nom_Gouvernorat_Ar).filter(Boolean);
    this.listGouvernorats = [...new Set(govs)].sort();
    const muns = this.allBudgetData.map(item => item.Nom_Municipalite_Ar).filter(Boolean);
    this.listMunicipalites = [...new Set(muns)].sort();
  }

  applyBudgetFilters() {
    this.filteredBudgetData = this.allBudgetData.filter(item => {
      const matchGov = this.selectedGov ? item.Nom_Gouvernorat_Ar === this.selectedGov : true;
      const matchMun = this.selectedMun ? item.Nom_Municipalite_Ar === this.selectedMun : true;
      return matchGov && matchMun;
    });
    this.renderBudgetLayer(this.filteredBudgetData);
  }

  resetFilters() {
    this.selectedGov = '';
    this.selectedMun = '';
    this.applyBudgetFilters();
  }

  renderBudgetLayer(data: any[]) {
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
    }

    const budgetCluster = L.markerClusterGroup({
      maxClusterRadius: 80, // Légèrement augmenté pour grouper plus large
      iconCreateFunction: (cluster) => {
        const markers = cluster.getAllChildMarkers();
        let totalPrevision = 0;
        
        // Sets pour détecter l'unicité des lieux
        const govs = new Set();
        const muns = new Set();

        markers.forEach((marker: any) => {
          // Somme
          if (marker.options.previsionAmount) {
            totalPrevision += marker.options.previsionAmount;
          }
          // Collecte des noms géographiques attachés au marker
          if (marker.options.govName) govs.add(marker.options.govName);
          if (marker.options.munName) muns.add(marker.options.munName);
        });

        // --- Logique de détermination du Nom ---
        let locationLabel = 'Zones Multiples'; // Par défaut
        let locationClass = 'mixed';

        if (muns.size === 1) {
          // Si une seule municipalité dans tout le cluster
          locationLabel = [...muns][0] as string;
          locationClass = 'municipalite';
        } else if (govs.size === 1) {
          // Si plusieurs municipalités mais un seul Gouvernorat
          locationLabel = [...govs][0] as string;
          locationClass = 'gouvernorat';
        } else {
            // Mélange de gouvernorats (ex: frontière Tunis/Ariana)
            locationLabel = 'Divers';
        }

        const formattedSum = new Intl.NumberFormat('fr-TN', { 
          style: 'currency', currency: 'TND', maximumFractionDigits: 0 
        }).format(totalPrevision);

        return L.divIcon({
          html: \`<div class="budget-cluster-icon \${locationClass}">
                   <span class="amount">\${formattedSum}</span>
                   <span class="location">\${locationLabel}</span>
                   <small>(\${markers.length} projets)</small>
                 </div>\`,
          className: 'budget-cluster',
          iconSize: L.point(100, 100) // Agrandir un peu pour le texte
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
        
        // ATTACHEMENT DES DONNÉES AU MARKER (Crucial pour le cluster)
        (marker.options as any)['previsionAmount'] = valPrevision;
        (marker.options as any)['govName'] = item.Nom_Gouvernorat_Ar;
        (marker.options as any)['munName'] = item.Nom_Municipalite_Ar;

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
  }

  loadStandardData(category: string) {
    this.mapService.getLocations().subscribe({
      next: (locations) => {
        const filtered = category === 'Toutes' 
          ? locations 
          : locations.filter(l => l.categorie === category);

        const standardCluster = L.markerClusterGroup();

        if (filtered) {
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
        }
        this.currentLayer = standardCluster;
        this.map.addLayer(this.currentLayer);
        if(filtered && filtered.length > 0) {
           const bounds = standardCluster.getBounds();
           if(bounds.isValid()) this.map.fitBounds(bounds);
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

# 2. Mise à jour du CSS pour gérer le texte (Nom de ville)
echo "🎨 Mise à jour de src/app/app.css..."
cat <<EOF > src/app/app.css
/* Layout Principal */
.map-container {
  position: relative;
  height: 100vh;
  width: 100%;
  display: flex;
  flex-direction: column;
}

#map {
  flex-grow: 1;
  width: 100%;
  height: 100%;
  z-index: 1;
}

/* Contrôles */
.map-controls {
  position: absolute;
  top: 20px;
  right: 20px;
  z-index: 1000;
  background: white;
  padding: 15px;
  border-radius: 8px;
  box-shadow: 0 4px 10px rgba(0,0,0,0.3);
  font-family: 'Segoe UI', Arial, sans-serif;
  min-width: 250px;
  max-width: 300px;
}
.main-select select { width: 100%; padding: 6px; margin-top: 5px; }

/* Filtres */
.filter-container { margin-top: 10px; animation: fadeIn 0.3s ease-in-out; }
.filter-header { display: flex; justify-content: space-between; margin-bottom: 10px; color: #28a745; }
.toggle-btn { background: none; border: none; color: #007bff; font-size: 11px; cursor: pointer; text-decoration: underline; }
.filter-group { margin-bottom: 8px; }
.filter-group label { display: block; font-size: 12px; color: #555; }
.filter-group select { width: 100%; padding: 4px; }
.reset-btn { width: 100%; padding: 6px; margin-top: 5px; background-color: #f8f9fa; border: 1px solid #ddd; cursor: pointer; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(-5px); } to { opacity: 1; transform: translateY(0); } }

/* --- CLUSTER BUDGET --- */
::ng-deep .budget-cluster-icon {
  background-color: rgba(40, 167, 69, 0.95);
  border: 2px solid white;
  border-radius: 50%;
  color: white;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  /* Augmentation de la taille pour le texte */
  width: 100px; 
  height: 100px; 
  box-shadow: 0 5px 15px rgba(0,0,0,0.4);
  text-align: center;
  cursor: pointer;
  transition: transform 0.2s;
  padding: 5px; /* Padding interne */
  overflow: hidden;
}

::ng-deep .budget-cluster-icon:hover {
  background-color: #218838;
  transform: scale(1.1);
  z-index: 9999;
}

/* Montant */
::ng-deep .budget-cluster-icon .amount {
  font-weight: bold;
  font-size: 11px;
  line-height: 1.2;
}

/* Nom Géographique (Gouvernorat/Municipalité) */
::ng-deep .budget-cluster-icon .location {
  font-size: 10px;
  font-weight: bold;
  color: #d4edda; /* Vert très clair */
  margin-top: 2px;
  margin-bottom: 2px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 90%;
}

::ng-deep .budget-cluster-icon small {
  font-size: 9px;
  opacity: 0.8;
  font-weight: normal;
}

/* Variation de couleur subtile si c'est une municipalité précise */
::ng-deep .budget-cluster-icon.municipalite {
  background-color: rgba(30, 126, 52, 0.95); /* Vert plus foncé */
  border-color: #c3e6cb;
}
EOF

echo "✅ Catégories mises à jour et affichage géographique activé !"