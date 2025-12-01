import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class MapDataService {
  constructor(private http: HttpClient) { }

  getLocations(): Observable<any[]> {
    // Les établissements classiques (Lycées, etc.)
    return this.http.get<any[]>('assets/all_locations.json');
  }

  getBudget2021(): Observable<any[]> {
    // Le fichier spécifique Budget
    return this.http.get<any[]>('assets/budget2021.json');
  }
}
