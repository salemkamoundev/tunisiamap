import { Component } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms'; // <--- Requis pour [(ngModel)]
import { LeafletModule } from '@bluehalo/ngx-leaflet'; 

import * as L from 'leaflet';
import 'leaflet.markercluster'; 
import { MapDataService } from './services/map-data.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, LeafletModule, HttpClientModule, FormsModule], // Ajout FormsModule
  templateUrl: './app.html',
  styleUrls: ['./app.css'],
  providers: [MapDataService]
})
export class App {
  map!: L.Map;
  currentLayer: any = null;

categories: string[] = [ 'Stade', 'Lycée', 'Maison des Jeunes', 'Poste', 'Université', 'École', 'Budget 2021' ];

  // --- Propriétés pour les Filtres Budget ---
  isBudgetActive: boolean = false;      // Est-ce que la catégorie Budget est choisie ?
  filtersVisible: boolean = true;       // Est-ce que le panneau filtre est déplié ?
  
  allBudgetData: any[] = [];            // Toutes les données brutes
  filteredBudgetData: any[] = [];       // Données filtrées affichées

  // Listes pour les dropdowns
  listGouvernorats: string[] = [];
  listMunicipalites: string[] = [];

  // Valeurs sélectionnées
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
    this.loadStandardData('Toutes');
  }

  onCategoryChange(event: any) {
    const selectedCat = event.target.value;
    
    // Reset de l'état des filtres
    this.isBudgetActive = (selectedCat === 'Budget 2021');
    
    // Nettoyage carte
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
      this.currentLayer = null;
    }

    if (this.isBudgetActive) {
      // Chargement initial des données Budget
      this.loadBudgetData();
    } else {
      this.loadStandardData(selectedCat);
    }
  }

  // --- GESTION DU BUDGET 2021 ---

  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        // 1. Sauvegarde des données brutes
        this.allBudgetData = data;
        
        // 2. Extraction des filtres (Gouvernorats uniques, etc.)
        this.extractFilterOptions();

        // 3. Application par défaut (tout afficher)
        this.applyBudgetFilters();
      },
      error: (err) => console.error('Erreur Budget:', err)
    });
  }

  // Extrait les listes uniques pour les Select
  extractFilterOptions() {
    // Récupérer les Gouvernorats uniques
    const govs = this.allBudgetData.map(item => item.Nom_Gouvernorat_Ar).filter(Boolean);
    this.listGouvernorats = [...new Set(govs)].sort();

    // On charge toutes les municipalités au début
    const muns = this.allBudgetData.map(item => item.Nom_Municipalite_Ar).filter(Boolean);
    this.listMunicipalites = [...new Set(muns)].sort();
  }

  // Appelé quand l'utilisateur change un filtre
  applyBudgetFilters() {
    // 1. Filtrer les données
    this.filteredBudgetData = this.allBudgetData.filter(item => {
      const matchGov = this.selectedGov ? item.Nom_Gouvernorat_Ar === this.selectedGov : true;
      const matchMun = this.selectedMun ? item.Nom_Municipalite_Ar === this.selectedMun : true;
      return matchGov && matchMun;
    });

    // 2. Si un gouvernorat est choisi, on pourrait filtrer la liste des municipalités ici (optionnel)
    // Pour l'instant on garde simple.

    // 3. Dessiner la carte avec les données filtrées
    this.renderBudgetLayer(this.filteredBudgetData);
  }

  // Réinitialiser les filtres
  resetFilters() {
    this.selectedGov = '';
    this.selectedMun = '';
    this.applyBudgetFilters();
  }

  // Dessine le Cluster Vert (réutilisé pour filtrage)
  renderBudgetLayer(data: any[]) {
    // Nettoyage préventif si on rafraîchit
    if (this.currentLayer && this.map) {
      this.map.removeLayer(this.currentLayer);
    }

    const budgetCluster = L.markerClusterGroup({
      maxClusterRadius: 60,
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
          html: `<div class="budget-cluster-icon">
                   <span>${formattedSum}</span>
                   <small>(${markers.length} mun.)</small>
                 </div>`,
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
  }

  // --- LOGIQUE STANDARD ---
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
            marker.bindPopup(`<b>${loc.nom}</b><br>${loc.categorie}`);
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
         rows += `
          <tr>
            <td style="font-weight:bold; color:#555; padding:3px; border-bottom:1px solid #eee;">${key}</td>
            <td style="padding:3px; border-bottom:1px solid #eee;">${data[key]}</td>
          </tr>`;
      }
    }
    return `<div style="max-height:300px; overflow-y:auto; min-width:250px;">
              <h3 style="margin-top:0; color:#28a745; font-size:14px;">Détails</h3>
              <table style="width:100%; border-collapse:collapse; font-size:12px;"><tbody>${rows}</tbody></table>
            </div>`;
  }
}
