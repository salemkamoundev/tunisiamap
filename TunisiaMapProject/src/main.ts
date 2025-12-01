import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

// NOTE : Aucune importation de Leaflet ici.
// Leaflet est chargé globalement par le CDN dans index.html.

bootstrapApplication(AppComponent, appConfig)
  .catch((err) => console.error(err));
