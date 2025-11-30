import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { MapDataService, Location } from './services/map-data.service';
import * as L from 'leaflet';
import { forkJoin } from 'rxjs';

// On garde l'import pour le typage, mais le chargement réel se fait via angular.json
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

  // Options de base
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
    forkJoin({
      locations: this.mapDataService.getLocations(),
      geoJson: this.mapDataService.getGovernorates()
    }).subscribe({
      next: (data) => {
        // Gestion des lieux
        if (data.locations && data.locations.length > 0) {
          this.allLocations = data.locations;
          const uniqueCats = new Set(this.allLocations.map(l => l.categorie).filter(c => c));
          this.categories = Array.from(uniqueCats).sort();
        }
        // Gestion des frontières (Contours Noires)
        if (data.geoJson) {
            this.initGeoJsonLayer(data.geoJson);
        }
      },
      error: (err) => console.error('Erreur chargement:', err)
    });
  }

  // Initialisation des contours des gouvernorats
  initGeoJsonLayer(geoJsonData: any) {
    this.geoJsonLayer = L.geoJSON(geoJsonData, {
      style: (feature) => ({
        color: '#000000', weight: 2, opacity: 1, fillColor: '#FF1493', fillOpacity: 0.1
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

  // Popup statistique
  showGovernorateStats(event: any, feature: any) {
    const govName = feature.properties.name_fr || feature.properties.name_ar || 'Zone';
    const locationsInGov = this.allLocations.filter(loc => this.isPointInLayer(loc, event.target));
    
    const stats: any = {};
    locationsInGov.forEach(l => stats[l.categorie] = (stats[l.categorie] || 0) + 1);

    let statsHtml = '';
    for (const [cat, count] of Object.entries(stats)) {
      statsHtml += `<li><b>${cat}:</b> ${count}</li>`;
    }
    if (locationsInGov.length === 0) statsHtml = '<li>Aucun lieu trouvé</li>';

    L.popup()
      .setLatLng(event.latlng)
      .setContent(`<div><h3 style="color:#000; margin:0 0 10px 0;">${govName}</h3><p>Total : ${locationsInGov.length}</p><ul style="padding-left:20px; font-size:13px;">${statsHtml}</ul></div>`)
      .openOn(event.target._map);
  }

  isPointInLayer(loc: Location, layer: any): boolean {
    const latLng = L.latLng(loc.lat, loc.lng);
    return layer.getBounds && layer.getBounds().contains(latLng);
  }

  onCategoryChange(event: Event) {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedCategory = selectElement.value;
    this.updateMarkers();
  }

  updateMarkers() {
    // Nettoyage de l'ancien cluster
    if (this.markerClusterGroup) {
      const index = this.layers.indexOf(this.markerClusterGroup);
      if (index > -1) this.layers.splice(index, 1);
      this.markerClusterGroup.clearLayers();
    }
    
    if (!this.selectedCategory) return;

    const filtered = this.allLocations.filter(l => l.categorie === this.selectedCategory);

    // CRÉATION DU CLUSTER AVEC CAST DE SÉCURITÉ
    // L as any permet d'éviter l'erreur de compilation si les types sont absents
    // Mais le script JS dans angular.json assure que la fonction existe au runtime.
    this.markerClusterGroup = (L as any).markerClusterGroup({ 
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

    if (this.markerClusterGroup) {
        this.markerClusterGroup.addLayers(markers);
        this.layers = [...this.layers, this.markerClusterGroup];
    }
  }

  onMapReady(map: L.Map) {}
}
