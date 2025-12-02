#!/bin/bash

echo "🚑 Correction des données Recettes (Jointure GPS + Mapping des champs)..."

# 1. MISE À JOUR DE APP.COMPONENT.TS
# On ajoute forkJoin pour charger les deux fichiers en parallèle
# On ajoute une logique de mapping pour convertir FIELD1, FIELD2... en noms lisibles
echo "💻 Réécriture de src/app/app.component.ts..."
cat <<EOF > src/app/app.component.ts
import { Component, AfterViewInit } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms'; 
import { forkJoin } from 'rxjs'; // Pour charger 2 fichiers en même temps
import { MapDataService } from './services/map-data.service';

declare const L: any;

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, HttpClientModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
  providers: [MapDataService]
})
export class AppComponent implements AfterViewInit {
  map!: any;
  currentLayer: any = null;
  activeLayers: any[] = [];

  categories: string[] = [ 
    'Stade', 'Lycée', 'Maison des Jeunes', 'Poste', 'Université', 'École', 
    'Budget 2021', 'Recette Municipalités' 
  ];

  isBudgetActive: boolean = false;
  isRecetteActive: boolean = false;
  filtersVisible: boolean = true;
  
  allBudgetData: any[] = [];
  allRecetteData: any[] = [];
  
  // Listes pour les filtres
  listGouvernorats: string[] = [];
  listMunicipalites: string[] = [];
  
  selectedGov: string = '';
  selectedMun: string = '';

  // Données filtrées
  currentFilteredData: any[] = [];

  constructor(private mapService: MapDataService) {}

  ngAfterViewInit() {
    setTimeout(() => {
        if (typeof L !== 'undefined') this.initMap();
    }, 200);
  }

  initMap() {
    this.map = L.map('map').setView([33.8869, 9.5375], 7);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map);
    this.loadStandardData('Toutes');
  }

  onCategoryChange(event: any) {
    const selectedCat = event.target.value;
    
    // Reset
    this.isBudgetActive = (selectedCat === 'Budget 2021');
    this.isRecetteActive = (selectedCat === 'Recette Municipalités');
    this.selectedGov = '';
    this.selectedMun = '';
    this.listGouvernorats = [];
    this.listMunicipalites = [];
    this.clearMap();

    if (this.isBudgetActive) {
      this.loadBudgetData();
    } else if (this.isRecetteActive) {
      this.loadRecetteData();
    } else {
      this.loadStandardData(selectedCat);
    }
  }

  clearMap() {
    if (this.currentLayer) this.map.removeLayer(this.currentLayer);
    this.activeLayers.forEach(l => this.map.removeLayer(l));
    this.activeLayers = [];
    this.currentLayer = null;
  }

  // --- 1. CHARGEMENT BUDGET (inchangé) ---
  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        this.allBudgetData = data;
        this.prepareFilters(data, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar');
        this.currentFilteredData = data;
        this.renderHierarchicalCluster(data, 'budget');
      },
      error: (e) => console.error(e)
    });
  }

  // --- 2. CHARGEMENT RECETTE (Nouveau : Jointure avec Budget pour GPS) ---
  loadRecetteData() {
    // On charge Budget (pour les coords) ET Recettes (pour les montants)
    forkJoin({
      budget: this.mapService.getBudget2021(),
      recette: this.mapService.getRecetteMunicipalites()
    }).subscribe({
      next: (res) => {
        // 1. Création d'un dictionnaire de coordonnées depuis le Budget
        // Clé = Code Municipalité (Code_Municipalite_INS)
        const coordsMap = new Map();
        res.budget.forEach((b: any) => {
          if (b.lat && b.lng && b.Code_Municipalite_INS) {
            coordsMap.set(b.Code_Municipalite_INS, { lat: b.lat, lng: b.lng });
          }
        });

        // 2. Nettoyage et Enrichissement des Recettes
        const mergedData: any[] = [];
        
        res.recette.forEach((r: any) => {
          // On ignore la ligne d'en-tête si elle existe ("FIELD1" == "Code_Municipalite_INS")
          if (r.FIELD1 === 'Code_Municipalite_INS') return;

          // On récupère les coords via le code municipalité (FIELD1)
          const coords = coordsMap.get(r.FIELD1);

          if (coords) {
            mergedData.push({
              // On garde les données d'origine
              ...r,
              // On ajoute les coords
              lat: coords.lat,
              lng: coords.lng,
              // On mappe les champs cryptiques vers des noms lisibles pour notre code
              Nom_Municipalite_Ar: r.FIELD2,
              Nom_Gouvernorat_Ar: r.FIELD3,
              recettes_previsions: r.FIELD20,
              recettes_realisations: r.FIELD21,
              // libellé article (utile pour le popup)
              lib_article: r.FIELD16 
            });
          }
        });

        this.allRecetteData = mergedData;
        
        // 3. Initialisation des filtres et affichage
        this.prepareFilters(mergedData, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar');
        this.currentFilteredData = mergedData;
        this.renderHierarchicalCluster(mergedData, 'recette');
      },
      error: (e) => console.error('Erreur chargement jointure:', e)
    });
  }

  // --- FILTRES ---
  prepareFilters(data: any[], govKey: string, munKey: string) {
    const govs = data.map(item => item[govKey]).filter(Boolean);
    this.listGouvernorats = [...new Set(govs)].sort();
    const muns = data.map(item => item[munKey]).filter(Boolean);
    this.listMunicipalites = [...new Set(muns)].sort();
  }

  applyFilters() {
    const sourceData = this.isBudgetActive ? this.allBudgetData : this.allRecetteData;
    const type = this.isBudgetActive ? 'budget' : 'recette';
    
    // Grâce au mapping, on utilise les mêmes clés pour les deux !
    const govKey = 'Nom_Gouvernorat_Ar';
    const munKey = 'Nom_Municipalite_Ar';

    this.currentFilteredData = sourceData.filter(item => {
      const matchGov = this.selectedGov ? item[govKey] === this.selectedGov : true;
      const matchMun = this.selectedMun ? item[munKey] === this.selectedMun : true;
      return matchGov && matchMun;
    });

    this.renderHierarchicalCluster(this.currentFilteredData, type);
  }

  resetFilters() {
    this.selectedGov = '';
    this.selectedMun = '';
    this.applyFilters();
  }

  // --- RENDU CLUSTER ---
  renderHierarchicalCluster(data: any[], type: 'budget' | 'recette') {
    this.clearMap();

    const groupedByGov: { [key: string]: any[] } = {};
    const govKey = 'Nom_Gouvernorat_Ar'; 

    data.forEach(item => {
      const g = item[govKey] || 'Autre';
      if (!groupedByGov[g]) groupedByGov[g] = [];
      groupedByGov[g].push(item);
    });

    Object.keys(groupedByGov).forEach(govName => {
      const groupData = groupedByGov[govName];
      const cluster = L.markerClusterGroup({
        maxClusterRadius: 80,
        iconCreateFunction: (c: any) => this.createClusterIcon(c, govName, type)
      });

      groupData.forEach(item => {
        const marker = this.createMarker(item, type);
        if (marker) cluster.addLayer(marker);
      });

      this.activeLayers.push(cluster);
      this.map.addLayer(cluster);
    });

    if (this.activeLayers.length > 0) {
       const bounds = this.activeLayers[0].getBounds();
       if(bounds.isValid()) this.map.fitBounds(bounds);
    }
  }

  createClusterIcon(cluster: any, defaultLabel: string, type: 'budget' | 'recette') {
    const markers = cluster.getAllChildMarkers();
    let total = 0;
    const muns = new Set();

    markers.forEach((m: any) => {
      if (m.options.amount) total += m.options.amount;
      if (m.options.munName) muns.add(m.options.munName);
    });

    let label = defaultLabel;
    let cssType = type === 'budget' ? 'gouvernorat' : 'recette-gov'; 
    let cssSub = type === 'budget' ? 'municipalite' : 'recette-mun';

    if (muns.size === 1) {
      label = [...muns][0] as string;
      cssType = cssSub;
    }

    const fmt = new Intl.NumberFormat('fr-TN', { 
      style: 'currency', currency: 'TND', maximumFractionDigits: 0 
    }).format(total);

    return L.divIcon({
      html: \`<div class="budget-cluster-icon \${cssType}">
               <span class="amount">\${fmt}</span>
               <span class="location">\${label}</span>
               <small>(\${markers.length})</small>
             </div>\`,
      className: 'budget-cluster',
      iconSize: L.point(100, 100)
    });
  }

  createMarker(item: any, type: 'budget' | 'recette') {
    const lat = parseFloat(item.lat);
    const lng = parseFloat(item.lng);
    
    let rawAmount = '0';
    if (type === 'budget') rawAmount = item.depenses_prevision;
    if (type === 'recette') rawAmount = item.recettes_previsions || item.FIELD20; // Support FIELD20

    if (isNaN(lat) || isNaN(lng)) return null;

    const val = parseFloat(String(rawAmount).replace(/\s/g, '').replace(',', '.'));

    const marker = L.marker([lat, lng], {
      icon: L.icon({
        iconUrl: 'assets/marker-icon.png',
        shadowUrl: 'assets/marker-shadow.png',
        iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34]
      })
    });

    (marker as any).options.amount = val;
    (marker as any).options.govName = item.Nom_Gouvernorat_Ar;
    (marker as any).options.munName = item.Nom_Municipalite_Ar;

    marker.bindPopup(this.generateFullPopup(item));
    return marker;
  }

  // --- STANDARDS ---
  loadStandardData(cat: string) {
    this.mapService.getLocations().subscribe({
      next: (locs) => {
        const filtered = cat === 'Toutes' ? locs : locs.filter(l => l.categorie === cat);
        const cluster = L.markerClusterGroup();
        if(filtered) {
            filtered.forEach(l => {
               const lat = parseFloat(l.lat);
               const lng = parseFloat(l.lng);
               if(!isNaN(lat) && !isNaN(lng)) {
                   const m = L.marker([lat, lng], {
                     icon: L.icon({
                       iconUrl: 'assets/marker-icon.png',
                       shadowUrl: 'assets/marker-shadow.png',
                       iconSize: [25, 41], iconAnchor: [12, 41]
                     })
                   });
                   m.bindPopup(\`<b>\${l.nom}</b><br>\${l.categorie}\`);
                   cluster.addLayer(m);
               }
            });
        }
        this.activeLayers.push(cluster);
        this.map.addLayer(cluster);
        if(filtered && filtered.length > 0) {
            const b = cluster.getBounds();
            if(b.isValid()) this.map.fitBounds(b);
        }
      }
    });
  }

  generateFullPopup(data: any): string {
    let rows = '';
    // On affiche tout sauf les champs techniques qu'on a ajoutés ou qui sont redondants
    const ignore = ['lat', 'lng', 'Code_Municipalite_INS', 'Nom_Municipalite_Ar', 'Nom_Gouvernorat_Ar', 'recettes_previsions', 'recettes_realisations', 'FIELD1', 'FIELD3', 'FIELD4'];
    
    for (const key in data) {
      if (!ignore.includes(key)) {
         rows += \`<tr><td style="font-weight:bold; padding:2px 5px">\${key}</td><td style="padding:2px 5px">\${data[key]}</td></tr>\`;
      }
    }
    // On ajoute proprement les champs importants en haut
    const header = \`
        <tr><td style="font-weight:bold">Municipalité</td><td>\${data.Nom_Municipalite_Ar}</td></tr>
        <tr><td style="font-weight:bold">Gouvernorat</td><td>\${data.Nom_Gouvernorat_Ar}</td></tr>
        <tr><td style="font-weight:bold">Prévisions</td><td>\${data.recettes_previsions}</td></tr>
    \`;

    return \`<div style="max-height:300px;overflow:auto;font-size:12px"><table>\${header}\${rows}</table></div>\`;
  }
}
EOF

echo "✅ Script appliqué : Les recettes sont maintenant géolocalisées via le fichier Budget !"