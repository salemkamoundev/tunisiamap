import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { MapDataService, Location } from './services/map-data.service';
import * as L from 'leaflet';

// Import indispensable pour le fonctionnement du clustering
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
  selectedCategory: string = ''; // Vide par défaut

  // Options de base de la carte
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

  // On stocke le groupe de clusters ici
  markerClusterGroup: L.MarkerClusterGroup | undefined;
  
  // Couches à afficher (contient le clusterGroup)
  layers: L.Layer[] = [];

  constructor(private mapDataService: MapDataService) {}

  ngOnInit() {
    this.mapDataService.getLocations().subscribe({
      next: (locations: Location[]) => {
        this.allLocations = locations;
        const uniqueCats = new Set(locations.map(l => l.categorie).filter(c => c));
        this.categories = Array.from(uniqueCats).sort();
        console.log(`✅ ${locations.length} lieux chargés.`);
      },
      error: (err) => console.error('Erreur:', err)
    });
  }

  onCategoryChange(event: Event) {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedCategory = selectElement.value;
    this.updateMarkers();
  }

  updateMarkers() {
    // 1. Filtrer les données
    if (!this.selectedCategory) {
      this.layers = [];
      return;
    }
    const filtered = this.allLocations.filter(l => l.categorie === this.selectedCategory);

    // 2. Créer (ou recréer) le groupe de clusters
    // On peut passer des options ici, ex: { chunkedLoading: true } pour la performance
    this.markerClusterGroup = L.markerClusterGroup({ animate: true });

    // 3. Créer les marqueurs individuels
    const markers = filtered.map(loc => {
      return L.marker([loc.lat, loc.lng], {
        icon: L.icon({
          iconSize: [25, 41],
          iconAnchor: [13, 41],
          iconUrl: 'assets/marker-icon.png',
          shadowUrl: 'assets/marker-shadow.png'
        }),
        title: loc.nom
      }).bindPopup(`
        <div style="text-align:center;">
          <strong style="color:#007bff;">${loc.nom}</strong><br>
          <span style="color:#666;">${loc.categorie}</span>
        </div>
      `);
    });

    // 4. Ajouter les marqueurs au GROUPE DE CLUSTERS (pas directement à la carte)
    this.markerClusterGroup.addLayers(markers);

    // 5. Mettre à jour la couche Angular avec le groupe
    this.layers = [this.markerClusterGroup];
  }

  onMapReady(map: L.Map) {
    // Carte prête
  }
}
