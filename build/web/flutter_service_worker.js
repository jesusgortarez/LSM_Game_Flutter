'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "46e2a42edee5755e5a6ec605cc74335d",
"assets/AssetManifest.bin.json": "7e3876daef76a2127dc0fcd3af8c4249",
"assets/AssetManifest.json": "4cdded2ab81ac111159e420c01a9fcd0",
"assets/assets/Nivel_1/A6.png": "b8eee0e9712c847c88ab691c1a2a3759",
"assets/assets/Nivel_1/A6_ilustraciones/11.jpg": "b29f65946a87d7db29c4e2675fbdd7b9",
"assets/assets/Nivel_1/A6_ilustraciones/16.jpg": "bc5d7e739df72c4dd9e68452234a19b1",
"assets/assets/Nivel_1/A6_ilustraciones/ardilla.jpg": "0bf8ccde2b6cff15bfff7873e0db8f7a",
"assets/assets/Nivel_1/A6_ilustraciones/arroz.jpg": "7353c0a02549c2ceea97104b2eb168f5",
"assets/assets/Nivel_1/A6_ilustraciones/auto.jpg": "29b3b0dde0fdffd84b024f93e6657908",
"assets/assets/Nivel_1/A6_ilustraciones/biberon.png": "3130040f3901a4bc993d1db417c23516",
"assets/assets/Nivel_1/A6_ilustraciones/ciego.jpg": "eeac909321d7727cb165d69573de0d1f",
"assets/assets/Nivel_1/A6_ilustraciones/numero-6-1.jpg": "c15752daa398eebcd9ab61c65f10d99d",
"assets/assets/Nivel_1/A6_ilustraciones/pan.jpg": "1c08060d7f57660ede1a09fc67f52e22",
"assets/assets/Nivel_1/A6_ilustraciones/piojo.jpg": "fdf3905fddb14f0bda267cdde9f989c4",
"assets/assets/Nivel_1/A6_ilustraciones/tortuga.jpg": "774de12f47a97c4ac7d016b6e77906a2",
"assets/assets/Nivel_1/B.png": "6a51bdd520cd4b223ddb0fb0cf9fe0eb",
"assets/assets/Nivel_1/B_ilustraciones/barco.jpg": "945d3d8b56c693e38d3c376ba025ed7e",
"assets/assets/Nivel_1/B_ilustraciones/brocha.jpg": "9d42e8d87dc0595dae9cc56e1005eaeb",
"assets/assets/Nivel_1/B_ilustraciones/bruja.jpg": "95a81e22eee8cbc9007995451af68079",
"assets/assets/Nivel_1/B_ilustraciones/burro.jpg": "9584d70effe8198cab0143c62406051c",
"assets/assets/Nivel_1/B_ilustraciones/claqueta.jpg": "a2c6fdba3f36ef2526c2e547dfd9d81b",
"assets/assets/Nivel_1/B_ilustraciones/elefante.jpg": "915cf0cc160a6a2e27531594c2680f2e",
"assets/assets/Nivel_1/B_ilustraciones/espejo.jpg": "d2749df20e021c3dec36bbde157f52c1",
"assets/assets/Nivel_1/B_ilustraciones/fantasma.jpg": "5d8a80d2ce6338426687464236959b83",
"assets/assets/Nivel_1/B_ilustraciones/librero.jpg": "572bad36c8178c84b2855fd4a3484e4c",
"assets/assets/Nivel_1/B_ilustraciones/libros.jpg": "730864db88f18fbde05e4e15a9ff13a3",
"assets/assets/Nivel_1/B_ilustraciones/pez.jpg": "910b19da2f40e34c546d7fc024448f72",
"assets/assets/Nivel_1/B_ilustraciones/servilleta.jpg": "01113e04506ef3369fe6403073b1608d",
"assets/assets/Nivel_1/B_ilustraciones/taco.jpg": "40a8e5f3279121a31629450ac50ec478",
"assets/assets/Nivel_2/C.png": "7f54eb65b23b83927107f2bbc8d19ee7",
"assets/assets/Nivel_2/C_ilustraciones/calle.jpg": "2af699457671daa400cf8aac010ffdf3",
"assets/assets/Nivel_2/C_ilustraciones/calor.jpg": "1ad30e3f949e1ccf8cdd531b183fe578",
"assets/assets/Nivel_2/C_ilustraciones/cama.jpg": "0b39c398aa6173dffd63a00cf97826bc",
"assets/assets/Nivel_2/C_ilustraciones/camion.jpg": "71880047fbbbae8265bfca8f2c308b7e",
"assets/assets/Nivel_2/C_ilustraciones/cantar.jpg": "1cce7cdfabf295211116b03cf281e2ec",
"assets/assets/Nivel_2/C_ilustraciones/cerradura.jpg": "53110b355be4173b872afda3500fbd69",
"assets/assets/Nivel_2/C_ilustraciones/chef.jpg": "62b5ccd75b61e5aa7652c9b58282ca70",
"assets/assets/Nivel_2/C_ilustraciones/cielo.jpg": "e72a261f6762226b97169f15b9e854cd",
"assets/assets/Nivel_2/C_ilustraciones/ciencia.jpg": "c390ee1dcfb5cb844e87971c5a4aae26",
"assets/assets/Nivel_2/DZ.png": "2843139315b2842c28343734178eb23b",
"assets/assets/Nivel_2/DZ_ilustraciones/caballo.jpg": "dadbceabf51ce6adcac0ea45a0b0126f",
"assets/assets/Nivel_2/DZ_ilustraciones/colaperro.jpg": "fe7c65d5f10c233e83f722662339b54f",
"assets/assets/Nivel_2/DZ_ilustraciones/diccionario.jpg": "cc0b3959eeba61214b6ed6b0f67f5293",
"assets/assets/Nivel_2/DZ_ilustraciones/diente.jpg": "d3c461f64e42dc284479930f4093360c",
"assets/assets/Nivel_2/DZ_ilustraciones/guayaba.jpg": "83496614ca69dfdec2d79fdc718cd3b4",
"assets/assets/Nivel_2/DZ_ilustraciones/gusano.jpg": "b2c92e0f716ccdf2261693642981dd72",
"assets/assets/Nivel_2/DZ_ilustraciones/hermano.jpg": "ed1c533da5d6b66a6eacd62cb88d5cc1",
"assets/assets/Nivel_2/DZ_ilustraciones/hotdog.jpg": "ab9828eb50c23c8c9ecaa99f3c355e03",
"assets/assets/Nivel_2/DZ_ilustraciones/iglesia.jpg": "020ffe121813e1e6487ec2169bae6107",
"assets/assets/Nivel_2/DZ_ilustraciones/lagrimas.jpg": "234fe4561e2d17da34536aea9216568d",
"assets/assets/Nivel_2/DZ_ilustraciones/lapiz.jpg": "977b56a6810b186dbf74e803eff0a8fe",
"assets/assets/Nivel_2/DZ_ilustraciones/pecas.jpg": "67fe2df4212964efdaf12fa746770b22",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "4c7a8754153e3dec8e7a04055ea75c75",
"assets/NOTICES": "b8abfb64b70728e64c116f813756c16b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "4c174232b107d3621d1359dea58260b0",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "259e25bff512b11a6bdb57b895348e7e",
"/": "259e25bff512b11a6bdb57b895348e7e",
"main.dart.js": "30d2f691c26a8c4d61d27007839b3805",
"manifest.json": "00faf633024b5c91e3bfc134c7efebfe",
"version.json": "8030399cb1762e426e392dc09d35b609"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
