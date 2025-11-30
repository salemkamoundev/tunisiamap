#!/bin/bash

echo "🚫 Désactivation de l'interactivité sur les contours (GeoJSON)..."

# Réécriture de src/app/app.ts avec l'option interactive: false
cat > src/app/app.ts <<EOF
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { MapDataService, Location } from './services/map-data.service';
import { forkJoin } from 'rxjs';
import * as L from 'leaflet';

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
  
  // Options de la carte
  options: any;
  
  markerClusterGroup: any;
  geoJsonLayer: any;
  layers: any[] = [];
  
  private isPluginLoaded = false;

  constructor(private mapDataService: MapDataService) {}

  ngOnInit() {
    this.options = {
      layers: [
        L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
          maxZoom: 19,
          attribution: '&copy; OpenStreetMap &copy; CARTO'
        })
      ],
      zoom: 7,
      center: L.latLng(34.0, 9.0)
    };

    this.initializeMapData();
  }

  async initializeMapData() {
    (window as any).L = L;

    try {
      await import('leaflet.markercluster');
      this.isPluginLoaded = true;
    } catch (e) {
      console.error('Erreur chargement plugin', e);
    }

    this.loadData();
  }

  loadData() {
    this.fixIcons();

    forkJoin({
      locations: this.mapDataService.getLocations(),
      geoJson: this.mapDataService.getGovernorates()
    }).subscribe({
      next: (data) => {
        if (data.locations && data.locations.length > 0) {
          this.allLocations = data.locations;
          const uniqueCats = new Set(this.allLocations.map(l => l.categorie).filter(c => c));
          this.categories = Array.from(uniqueCats).sort();
          
          if (this.isPluginLoaded) {
            this.updateMarkers(this.allLocations);
          }
        }

        if (data.geoJson) {
            this.initGeoJsonLayer(data.geoJson);
        }
      },
      error: (err) => console.error('Erreur chargement:', err)
    });
  }

  fixIcons() {
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
      // --- MODIFICATION ICI : interactive: false ---
      // Cela empêche la classe 'leaflet-interactive' d'être ajoutée
      // Les contours ne captureront plus les clics de souris
      interactive: false, 
      
      style: (feature: any) => ({
        color: '#333', 
        weight: 1, 
        opacity: 0.6, 
        fillColor: 'transparent', 
        fillOpacity: 0
      })
      // J'ai supprimé 'onEachFeature' car avec interactive:false, 
      // les événements mouseover/click ne fonctionnent plus de toute façon.
    });
    this.layers.push(this.geoJsonLayer);
  }

  onCategoryChange(event: Event) {
    const selectElement = event.target as HTMLSelectElement;
    this.selectedCategory = selectElement.value;
    
    if (this.selectedCategory) {
      const filtered = this.allLocations.filter(l => l.categorie === this.selectedCategory);
      this.updateMarkers(filtered);
    } else {
       this.updateMarkers(this.allLocations);
    }
  }

  updateMarkers(locations: Location[]) {
    if (!this.isPluginLoaded) return;

    if (this.markerClusterGroup) {
      this.layers = this.layers.filter(l => l !== this.markerClusterGroup);
    }

    if (!(L as any).markerClusterGroup) {
        const GlobalL = (window as any).L;
        if (GlobalL && GlobalL.markerClusterGroup) {
            this.createClusterGroup(GlobalL, locations);
            return;
        }
        return;
    }

    this.createClusterGroup(L, locations);
  }

  createClusterGroup(LeafletObj: any, locations: Location[]) {
    this.markerClusterGroup = LeafletObj.markerClusterGroup({ 
      maxClusterRadius: 80,
      animate: true,
      spiderfyOnMaxZoom: true,
      showCoverageOnHover: false,
      iconCreateFunction: function (cluster: any) {
        const childCount = cluster.getChildCount();
        let c = ' marker-cluster-';
        if (childCount < 10) c += 'small';
        else if (childCount < 100) c += 'medium';
        else c += 'large';

        return new L.DivIcon({ 
          html: '<div><span>' + childCount + '</span></div>', 
          className: 'custom-cluster' + c, 
          iconSize: new L.Point(40, 40) 
        });
      }
    });

    const markers = locations.map(loc => {
      return L.marker([loc.lat, loc.lng], { title: loc.nom })
        .bindPopup(\`<div style="text-align:center"><b>\${loc.nom}</b><br><span style="color:#666">\${loc.categorie}</span></div>\`);
    });

    this.markerClusterGroup.addLayers(markers);
    this.layers = [...this.layers, this.markerClusterGroup];
  }

  onMapReady(map: any) {
    setTimeout(() => { map.invalidateSize(); }, 200);
  }
}
EOF

# Optionnel : On force le CSS pour être sûr à 100%
# Cela désactive les événements souris sur tous les chemins SVG (contours)
echo "🎨 Mise à jour du CSS pour ignorer les clics sur les tracés..."
cat >> src/app/app.css <<EOF

/* Force la désactivation des événements sur les polygones SVG */
/* Utile si Leaflet ajoute quand même la classe par erreur */
path.leaflet-interactive {
    pointer-events: none !important;
}
EOF

echo "✅ 'leaflet-interactive' supprimé (désactivé)."
echo "👉 Relancez 'ng build' et 'firebase deploy'."