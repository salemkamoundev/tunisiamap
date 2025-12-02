import { Component, AfterViewInit } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms'; 
import { MapDataService } from './services/map-data.service';

declare const L: any;

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, HttpClientModule, FormsModule],
  templateUrl: './app.html',
  styleUrls: ['./app.css'],
  providers: [MapDataService]
})
export class App implements AfterViewInit {
  map!: any;
  currentLayer: any = null;
  activeLayers: any[] = []; // Pour le multi-cluster

  categories: string[] = [ 
    'Stade', 'Lycée', 'Maison des Jeunes', 'Poste', 'Université', 'École', 
    'Budget 2021', 'Recette Municipalités' 
  ];

  // Etat
  currentCategory: string = 'Toutes';
  isBudgetActive: boolean = false;
  isRecetteActive: boolean = false;
  filtersVisible: boolean = true;
  
  // Données Budget
  allBudgetData: any[] = [];
  filteredBudgetData: any[] = [];
  
  // Données Recette
  allRecetteData: any[] = [];
  filteredRecetteData: any[] = [];

  // Listes Filtres (Partagées ou distinctes selon besoin)
  listGouvernorats: string[] = [];
  listMunicipalites: string[] = [];
  
  selectedGov: string = '';
  selectedMun: string = '';

  constructor(private mapService: MapDataService) {}

  ngAfterViewInit() {
    this.initMap();
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
    this.currentCategory = selectedCat;
    
    // Reset états
    this.isBudgetActive = (selectedCat === 'Budget 2021');
    this.isRecetteActive = (selectedCat === 'Recette Municipalités');
    
    // Reset Filtres UI
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

  // --- LOGIQUE COMMUNE FILTRES ---
  extractFilters(data: any[], govKey: string, munKey: string) {
    const govs = data.map(item => item[govKey]).filter(Boolean);
    this.listGouvernorats = [...new Set(govs)].sort();
    const muns = data.map(item => item[munKey]).filter(Boolean);
    this.listMunicipalites = [...new Set(muns)].sort();
  }

  applyFilters() {
    if (this.isBudgetActive) {
      this.filteredBudgetData = this.filterData(this.allBudgetData, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar');
      this.renderHierarchicalCluster(this.filteredBudgetData, 'budget');
    } else if (this.isRecetteActive) {
      // Mapping des clés si fichier brut (FIELD3 = Gov, FIELD2 = Mun)
      // Ou clés directes si fichier propre. Adaptez selon votre JSON réel.
      // Ici je suppose que le JSON a des clés propres comme dans Budget.
      // Si c'est FIELD3/FIELD2, changez ci-dessous.
      this.filteredRecetteData = this.filterData(this.allRecetteData, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar');
      this.renderHierarchicalCluster(this.filteredRecetteData, 'recette');
    }
  }

  filterData(data: any[], govKey: string, munKey: string) {
    return data.filter(item => {
      const matchGov = this.selectedGov ? item[govKey] === this.selectedGov : true;
      const matchMun = this.selectedMun ? item[munKey] === this.selectedMun : true;
      return matchGov && matchMun;
    });
  }

  resetFilters() {
    this.selectedGov = '';
    this.selectedMun = '';
    this.applyFilters();
  }

  // --- CHARGEMENT BUDGET ---
  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        this.allBudgetData = data;
        this.extractFilters(data, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar');
        this.filteredBudgetData = data;
        this.renderHierarchicalCluster(data, 'budget');
      },
      error: (e) => console.error(e)
    });
  }

  // --- CHARGEMENT RECETTE ---
  loadRecetteData() {
    this.mapService.getRecetteMunicipalites().subscribe({
      next: (data) => {
        // Mapping optionnel si données brutes FIELD...
        // data = data.map(d => ({ ...d, Nom_Gouvernorat_Ar: d.FIELD3, ... }));
        
        this.allRecetteData = data;
        // Adapter les clés si nécessaire (ex: FIELD3 pour Gov)
        this.extractFilters(data, 'Nom_Gouvernorat_Ar', 'Nom_Municipalite_Ar'); 
        this.filteredRecetteData = data;
        this.renderHierarchicalCluster(data, 'recette');
      },
      error: (e) => console.error(e)
    });
  }

  // --- RENDU HIERARCHIQUE GENERIQUE (Budget & Recette) ---
  renderHierarchicalCluster(data: any[], type: 'budget' | 'recette') {
    this.clearMap();

    const groupedByGov: { [key: string]: any[] } = {};
    const govKey = 'Nom_Gouvernorat_Ar'; // Ou FIELD3

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
    let cssType = type === 'budget' ? 'gouvernorat' : 'recette-gov'; // Classe CSS différente
    let cssSub = type === 'budget' ? 'municipalite' : 'recette-mun';

    if (muns.size === 1) {
      label = [...muns][0] as string;
      cssType = cssSub;
    }

    const fmt = new Intl.NumberFormat('fr-TN', { 
      style: 'currency', currency: 'TND', maximumFractionDigits: 0 
    }).format(total);

    return L.divIcon({
      html: `<div class="budget-cluster-icon ${cssType}">
               <span class="amount">${fmt}</span>
               <span class="location">${label}</span>
               <small>(${markers.length})</small>
             </div>`,
      className: 'budget-cluster',
      iconSize: L.point(100, 100)
    });
  }

  createMarker(item: any, type: 'budget' | 'recette') {
    const lat = parseFloat(item.lat);
    const lng = parseFloat(item.lng);
    
    // Clés dynamiques selon le type
    // Budget : depenses_prevision / Recette : recettes_previsions (ou FIELD20)
    let rawAmount = '0';
    if (type === 'budget') rawAmount = item.depenses_prevision;
    if (type === 'recette') rawAmount = item.recettes_previsions || item.FIELD20; // Supporte les 2 formats

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
    (marker as any).options.govName = item.Nom_Gouvernorat_Ar || item.FIELD3;
    (marker as any).options.munName = item.Nom_Municipalite_Ar || item.FIELD2;

    marker.bindPopup(this.generateFullPopup(item));
    return marker;
  }

  // --- STANDARDS ---
  loadStandardData(cat: string) {
    this.mapService.getLocations().subscribe({
      next: (locs) => {
        const filtered = cat === 'Toutes' ? locs : locs.filter(l => l.categorie === cat);
        const cluster = L.markerClusterGroup();
        filtered.forEach(l => {
           const m = L.marker([l.lat, l.lng], {
             icon: L.icon({
               iconUrl: 'assets/marker-icon.png',
               shadowUrl: 'assets/marker-shadow.png',
               iconSize: [25, 41], iconAnchor: [12, 41]
             })
           });
           m.bindPopup(`<b>${l.nom}</b><br>${l.categorie}`);
           cluster.addLayer(m);
        });
        this.activeLayers.push(cluster);
        this.map.addLayer(cluster);
        if(filtered.length > 0) {
            const b = cluster.getBounds();
            if(b.isValid()) this.map.fitBounds(b);
        }
      }
    });
  }

  generateFullPopup(data: any): string {
    let rows = '';
    for (const key in data) {
      if (data.hasOwnProperty(key) && key !== 'lat' && key !== 'lng') {
         rows += `<tr><td style="font-weight:bold">${key}</td><td>${data[key]}</td></tr>`;
      }
    }
    return `<div style="max-height:300px;overflow:auto"><table>${rows}</table></div>`;
  }
}
