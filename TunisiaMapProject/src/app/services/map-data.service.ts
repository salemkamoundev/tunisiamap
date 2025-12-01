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
  // Chemins vers vos fichiers JSON
  private locationsUrl = 'assets/all_locations.json';
  

  constructor(private http: HttpClient) { }

  // Récupère les points (écoles, lycées...)
  getLocations(): Observable<Location[]> {
    return this.http.get<Location[]>(this.locationsUrl);
  }
}
