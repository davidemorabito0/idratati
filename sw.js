/* IDRATATI — service worker.
   Tiene in cache il guscio dell'app e i tile dati, così la mappa si apre
   anche con la rete a un tacca. */
var V = 'idratati-v6-7';
var SHELL = [
  './', './index.html', './manifest.webmanifest',
  './icon-192.png', './apple-touch-icon.png',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js'
];

self.addEventListener('install', function(e){
  e.waitUntil(caches.open(V).then(function(c){
    return Promise.all(SHELL.map(function(u){
      return c.add(u).catch(function(){});
    }));
  }).then(function(){ return self.skipWaiting(); }));
});

self.addEventListener('activate', function(e){
  e.waitUntil(caches.keys().then(function(keys){
    return Promise.all(keys.filter(function(k){ return k!==V; })
                           .map(function(k){ return caches.delete(k); }));
  }).then(function(){ return self.clients.claim(); }));
});

self.addEventListener('fetch', function(e){
  var url = e.request.url;
  if(e.request.method !== 'GET') return;
  // mai in cache: Supabase e Overpass devono essere sempre freschi
  if(url.indexOf('supabase.co') > -1 || url.indexOf('overpass') > -1 ||
     url.indexOf('nominatim') > -1) return;

  // tile della mappa e dati: prima la cache, poi la rete
  if(url.indexOf('/data/') > -1 || url.indexOf('basemaps.cartocdn') > -1){
    e.respondWith(
      caches.match(e.request).then(function(hit){
        var net = fetch(e.request).then(function(r){
          if(r.ok) caches.open(V).then(function(c){ c.put(e.request, r.clone()); });
          return r;
        }).catch(function(){ return hit; });
        return hit || net;
      })
    );
    return;
  }

  // Le pagine si prendono SEMPRE dalla rete, con la copia in cache usata
  // solo se la rete non c'è. Altrimenti resti prigioniero di una versione
  // vecchia e non te ne accorgi.
  var eUnaPagina = e.request.mode === 'navigate' ||
                   (e.request.headers.get('accept')||'').indexOf('text/html') > -1;

  e.respondWith(
    fetch(eUnaPagina ? new Request(e.request, {cache:'reload'}) : e.request)
      .then(function(r){
        if(r.ok && url.indexOf(self.location.origin) === 0){
          var cp = r.clone();
          caches.open(V).then(function(c){ c.put(e.request, cp); });
        }
        return r;
      })
      .catch(function(){ return caches.match(e.request); })
  );
});
