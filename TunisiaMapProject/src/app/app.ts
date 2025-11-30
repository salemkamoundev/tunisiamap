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
        .bindPopup(`
          <div style="font-family:sans-serif; text-align:center;">
            <h4 style="margin:0; color:#FF1493;">${loc.nom}</h4>
            <span style="background:#eee; padding:2px 6px; border-radius:4px; font-size:12px;">${loc.categorie}</span>
          </div>
        `);
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
