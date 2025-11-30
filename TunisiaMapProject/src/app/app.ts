import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { MapDataService, Location } from './services/map-data.service';
import * as L from 'leaflet';
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

  options = {
    layers: [
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18,
        attribution: '&copy; OpenStreetMap contributors'
      })
    ],
    zoom: 7,
    center: L.latLng(34.0, 9.0)
  };

  markerClusterGroup: L.MarkerClusterGroup | undefined;
  geoJsonLayer: L.GeoJSON | undefined;
  layers: L.Layer[] = [];

  constructor(private mapDataService: MapDataService) {}

  ngOnInit() {
    console.log("🚀 Initialisation...");

    // 1. CHARGEMENT DES LIEUX (Indépendant des frontières)
    this.mapDataService.getLocations().subscribe({
      next: (locations: Location[]) => {
        console.log(`📦 Données reçues : ${locations.length} lieux.`);
        this.allLocations = locations;

        // Extraction robuste des catégories
        const cats = new Set<string>();
        locations.forEach(l => {
          if (l.categorie && l.categorie.trim() !== "") {
            cats.add(l.categorie);
          }
        });

        this.categories = Array.from(cats).sort();
        console.log("📋 Catégories extraites :", this.categories);

        if (this.categories.length === 0) {
            alert("Aucune catégorie trouvée dans le fichier JSON ! Vérifiez la colonne 'categorie'.");
        }
      },
      error: (err) => {
        console.error("❌ Erreur chargement JSON lieux:", err);
        alert("Erreur de lecture du fichier all_locations.json");
      }
    });

    // 2. CHARGEMENT DES FRONTIÈRES (Indépendant)
    this.mapDataService.getGovernorates().subscribe({
      next: (geoJson) => this.initGeoJsonLayer(geoJson),
      error: (err) => console.warn("⚠️ Impossible de charger les frontières (ceci n'est pas bloquant).", err)
    });
  }

  // --- GESTION DES FRONTIÈRES (NOIR PAR DÉFAUT) ---
  initGeoJsonLayer(geoJsonData: any) {
    this.geoJsonLayer = L.geoJSON(geoJsonData, {
      style: (feature) => ({
        color: '#000000',      // Contour NOIR permanent
        weight: 2,
        opacity: 1,
        fillColor: '#FF1493',
        fillOpacity: 0.1
      }),
      onEachFeature: (feature, layer) => {
        layer.on('click', (e) => this.showGovernorateStats(e, feature));
        layer.on('mouseover', (e) => { 
           const l = e.target; 
           l.setStyle({ weight: 4, fillOpacity: 0.3 }); 
        });
        layer.on('mouseout', (e) => { 
           const l = e.target; 
           this.geoJsonLayer?.resetStyle(l); 
        });
      }
    });
    this.layers.push(this.geoJsonLayer);
  }

  // --- STATISTIQUES AU CLIC ---
  showGovernorateStats(event: any, feature: any) {
    const govName = feature.properties.name_fr || feature.properties.name_ar || 'Zone';
    const locationsInGov = this.allLocations.filter(loc => this.isPointInLayer(loc, event.target));
    
    const stats: any = {};
    locationsInGov.forEach(l => stats[l.categorie] = (stats[l.categorie] || 0) + 1);

    let statsHtml = '';
    for (const [cat, count] of Object.entries(stats)) {
      statsHtml += `<li><b>${cat}:</b> ${count}</li>`;
    }
    if (locationsInGov.length === 0) statsHtml = '<li>Aucun lieu trouvé ici</li>';

    L.popup()
      .setLatLng(event.latlng)
      .setContent(`
        <div>
          <h3 style="color:#000; margin:0 0 10px 0;">${govName}</h3>
          <p>Total : ${locationsInGov.length}</p>
          <ul style="padding-left:20px; font-size:13px;">${statsHtml}</ul>
        </div>
      `)
      .openOn(event.target._map);
  }

  isPointInLayer(loc: Location, layer: any): boolean {
    const latLng = L.latLng(loc.lat, loc.lng);
    return layer.getBounds && layer.getBounds().contains(latLng);
  }

  // --- FILTRAGE ET CLUSTERING ---
  onCategoryChange(event: Event) {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedCategory = selectElement.value;
    this.updateMarkers();
  }

  updateMarkers() {
    // Nettoyage ancien cluster
    if (this.markerClusterGroup) {
      const index = this.layers.indexOf(this.markerClusterGroup);
      if (index > -1) this.layers.splice(index, 1);
      this.markerClusterGroup.clearLayers();
    }
    
    if (!this.selectedCategory) return;

    const filtered = this.allLocations.filter(l => l.categorie === this.selectedCategory);

    // Création Cluster
    this.markerClusterGroup = L.markerClusterGroup({ 
      maxClusterRadius: 80, 
      disableClusteringAtZoom: 11,
      animate: true,
      showCoverageOnHover: true,
      polygonOptions: { color: '#FF1493', weight: 3, opacity: 0.8, fillColor: '#FF1493', fillOpacity: 0.1 }
    });

    const markers = filtered.map(loc => {
      return L.marker([loc.lat, loc.lng], {
        icon: L.icon({
          iconSize: [25, 41],
          iconAnchor: [13, 41],
          iconUrl: 'assets/marker-icon.png',
          shadowUrl: 'assets/marker-shadow.png'
        }),
        title: loc.nom
      }).bindPopup(`<b>${loc.nom}</b><br>${loc.categorie}`);
    });

    this.markerClusterGroup.addLayers(markers);
    
    // Force update Angular
    this.layers = [...this.layers, this.markerClusterGroup];
  }

  onMapReady(map: L.Map) {}
}
