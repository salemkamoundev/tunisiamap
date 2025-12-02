import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class MapDataService {
  constructor(private http: HttpClient) { }

  getLocations(): Observable<any[]> {
    return this.http.get<any[]>('assets/all_locations.json');
  }

  getBudget2021(): Observable<any[]> {
    return this.http.get<any[]>('assets/budget2021.json');
  }

  getRecetteMunicipalites(): Observable<any[]> {
    return this.http.get<any[]>('assets/recetteMunicipalites.json');
  }

  getDelegations(): Observable<any[]> {
    return this.http.get<any[]>('assets/delegations.json');
  }
}
