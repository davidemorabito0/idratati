/* IDRATATI — service worker.
   Sta in mezzo a ogni richiesta dell'app, quindi un suo errore non rompe
   una funzione sola: le rompe tutte, e in modo intermittente.

   La regola che si era persa: quando si prende in carico una richiesta,
   bisogna SEMPRE restituire una risposta. Se si restituisce "niente" —
   perché la cache è vuota e la rete ha singhiozzato — il browser la
   considera fallita e non riprova. Da fuori sembra che l'app vada a
   giorni alterni. */

var V = 'idratati-v7-2';

var SHELL = [
  './', './index.html', './manifest.webmanifest',
  './icon-192.png', './apple-touch-icon.png',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js'
];

self.addEventListener('install', function(e){
  e.waitUntil(
    caches.open(V)
      .then(function(c){
        return Promise.all(SHELL.map(function(u){ return c.add(u).catch(function(){}); }));
      })
      .then(function(){ return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function(e){
  e.waitUntil(
    caches.keys()
      .then(function(chiavi){
        return Promise.all(chiavi
          .filter(function(k){ return k !== V; })
          .map(function(k){ return caches.delete(k); }));
      })
      .then(function(){ return self.clients.claim(); })
  );
});

/* Una risposta di ripiego, per non restituire mai il vuoto. */
function nonDisponibile(){
  return new Response('', {status: 504, statusText: 'Non raggiungibile'});
}

/* Mette in cache senza far aspettare nessuno, e senza far saltare tutto
   se la cache è piena o negata. */
function conservaInSilenzio(richiesta, risposta){
  try {
    var copia = risposta.clone();
    caches.open(V).then(function(c){
      c.put(richiesta, copia).catch(function(){});
    }).catch(function(){});
  } catch(e){ /* pazienza */ }
}

self.addEventListener('fetch', function(e){
  if(e.request.method !== 'GET') return;

  var url = e.request.url;

  /* Roba che deve essere sempre fresca: non la tocchiamo nemmeno, così
     se qualcosa va storto è il browser a gestirlo, non noi. */
  if(url.indexOf('supabase.co') > -1 ||
     url.indexOf('overpass')    > -1 ||
     url.indexOf('nominatim')   > -1 ||
     url.indexOf('openstreetmap.org') > -1) return;

  /* Le pagine arrivano sempre dalla rete: altrimenti si resta prigionieri
     di una versione vecchia senza accorgersene. La cache serve solo se la
     rete non c'è davvero. */
  var eUnaPagina = e.request.mode === 'navigate' ||
                   (e.request.headers.get('accept') || '').indexOf('text/html') > -1;

  if(eUnaPagina){
    e.respondWith(
      fetch(new Request(e.request, {cache: 'reload'}))
        .then(function(r){
          if(r && r.ok) conservaInSilenzio(e.request, r);
          return r;
        })
        .catch(function(){
          return caches.match(e.request).then(function(hit){
            return hit || caches.match('./index.html').then(function(h2){
              return h2 || nonDisponibile();
            });
          });
        })
    );
    return;
  }

  /* Riquadri della mappa e archivi dei punti: se ce l'abbiamo lo diamo
     subito e aggiorniamo dietro le quinte; se non ce l'abbiamo lo
     chiediamo alla rete. In nessun caso si restituisce il vuoto. */
  e.respondWith(
    caches.match(e.request).then(function(hit){

      if(hit){
        // risposta immediata, aggiornamento in sottofondo
        fetch(e.request)
          .then(function(r){ if(r && r.ok) conservaInSilenzio(e.request, r); })
          .catch(function(){});
        return hit;
      }

      return fetch(e.request)
        .then(function(r){
          if(r && r.ok) conservaInSilenzio(e.request, r);
          return r;                       // anche un 404 è una risposta valida
        })
        .catch(function(){
          return nonDisponibile();        // mai "niente"
        });
    }).catch(function(){
      // perfino la lettura della cache può fallire: si prova la rete
      return fetch(e.request).catch(function(){ return nonDisponibile(); });
    })
  );
});
