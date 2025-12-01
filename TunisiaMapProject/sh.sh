#!/bin/bash

echo "🧹 NETTOYAGE COMPLET POUR CDN (Correction Production)..."

# 1. NETTOYAGE DE MAIN.TS (CRITIQUE)
# On retire les imports de leaflet qui causent le conflit.
echo "💻 Correction de src/main.ts..."
cat <<EOF > src/main.ts
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

// NOTE : Aucune importation de Leaflet ici.
// Leaflet est chargé globalement par le CDN dans index.html.

bootstrapApplication(AppComponent, appConfig)
  .catch((err) => console.error(err));
EOF

# 2. NETTOYAGE DE STYLES.CSS
# On retire les @import node_modules car le CSS est déjà dans index.html
echo "🎨 Correction de src/styles.css..."
cat <<EOF > src/styles.css
/* Styles globaux */
html, body { 
    height: 100%; 
    margin: 0; 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

/* Note: Les CSS de Leaflet sont chargés via CDN dans index.html */
EOF

# 3. VERIFICATION DE ANGULAR.JSON
# On s'assure qu'aucun script Leaflet n'est injecté par le build
cat <<EOF > fix-build-config.js
const fs = require('fs');
const fileName = 'angular.json';

try {
    const data = fs.readFileSync(fileName, 'utf8');
    const json = JSON.parse(data);
    const projectName = Object.keys(json.projects)[0];
    const buildOptions = json.projects[projectName].architect.build.options;

    // 1. On vide les scripts (Le CDN s'en charge)
    buildOptions.scripts = [];

    // 2. On nettoie les styles (Le CDN s'en charge pour Leaflet)
    // On ne garde que votre fichier styles.css
    buildOptions.styles = [
        "src/styles.css"
    ];

    fs.writeFileSync(fileName, JSON.stringify(json, null, 2));
    console.log("✅ angular.json nettoyé : plus de dépendances Leaflet dans le build.");

} catch (e) {
    console.error("❌ Erreur JS:", e);
}
EOF
node fix-build-config.js
rm fix-build-config.js

# 4. APP.COMPONENT.TS (Déjà correct dans votre envoi, mais on s'assure)
# On garde la version qui utilise "declare const L: any;"
echo "💻 Validation de src/app/app.component.ts..."
cat <<EOF > src/app/app.component.ts
import { Component, AfterViewInit } from '@angular/core';
import { CommonModule } from '@angular/common'; 
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms'; 
import { MapDataService } from './services/map-data.service';

// C'est la ligne magique qui connecte le CDN
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

  categories: string[] = [ 
    'Stade', 'Lycée', 'Maison des Jeunes', 'Poste', 'Université', 'École', 'Budget 2021' 
  ];

  isBudgetActive: boolean = false;
  filtersVisible: boolean = true;
  
  allBudgetData: any[] = [];
  filteredBudgetData: any[] = [];
  listGouvernorats: string[] = [];
  listMunicipalites: string[] = [];
  selectedGov: string = '';
  selectedMun: string = '';

  constructor(private mapService: MapDataService) {}

  ngAfterViewInit() {
    // Petit délai pour s'assurer que le CDN est prêt (sécurité)
    setTimeout(() => {
        if (typeof L !== 'undefined') {
            this.initMap();
        } else {
            console.error('Leaflet non chargé ! Vérifiez index.html');
        }
    }, 100);
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

  loadBudgetData() {
    this.mapService.getBudget2021().subscribe({
      next: (data) => {
        this.allBudgetData = data;
        this.extractFilterOptions();
        this.applyBudgetFilters();
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
      maxClusterRadius: 80,
      iconCreateFunction: (cluster: any) => {
        const markers = cluster.getAllChildMarkers();
        let totalPrevision = 0;
        const govs = new Set();
        const muns = new Set();

        markers.forEach((marker: any) => {
          if (marker.options.previsionAmount) totalPrevision += marker.options.previsionAmount;
          if (marker.options.govName) govs.add(marker.options.govName);
          if (marker.options.munName) muns.add(marker.options.munName);
        });

        let locationLabel = 'Zones Multiples';
        let locationClass = 'mixed';

        if (muns.size === 1) {
          locationLabel = [...muns][0] as string;
          locationClass = 'municipalite';
        } else if (govs.size === 1) {
          locationLabel = [...govs][0] as string;
          locationClass = 'gouvernorat';
        } else {
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
          iconSize: L.point(100, 100)
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
        
        (marker as any).options.previsionAmount = valPrevision;
        (marker as any).options.govName = item.Nom_Gouvernorat_Ar;
        (marker as any).options.munName = item.Nom_Municipalite_Ar;

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
        
        if (filtered && filtered.length > 0) {
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

# 5. NETTOYAGE CACHE ET BUILD
echo "🧹 Nettoyage..."
rm -rf .angular
rm -rf dist

echo "🏗️  Build de Production..."
ng build

echo "✅ Terminé."
echo "👉 Lancez maintenant : firebase deploy --only hosting"