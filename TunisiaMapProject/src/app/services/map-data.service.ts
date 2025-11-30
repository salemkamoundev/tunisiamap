import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Location {
  nom: string;
  categorie: string;
  lat: number;
  lng: number;
}

@Injectable({
  providedIn: 'root'
})
export class MapDataService {
  // Chemin absolu vers le fichier JSON
  private dataUrl = '/assets/all_locations.json';

  constructor(private http: HttpClient) { }

  getLocations(): Observable<Location[]> {
    return this.http.get<Location[]>(this.dataUrl);
  }
}
