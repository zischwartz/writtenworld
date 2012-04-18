(function() {
  var geoAlternative, geoFailed, geoHasPosition, geoSucceeded, geoWatch, nj,
    __hasProp = Object.prototype.hasOwnProperty;

  window.initializeGeo = function() {
    $.doTimeout('GeoPermissionTimer', 10 * 1000, function() {
      console.log('User did not respond for a while, switching to alt');
      geoAlternative();
      return false;
    });
    if (navigator.geolocation) {
      window.insertMessage('Welcome', "If your browser asks you if it's ok to use location, please click <b> allow</b>. Otherwise, we'll try to find you based on your IP in a few seconds. <br> <a href='#' class='cancelAltGeo btn'>Or click here to stay right here</a>", 'major alert-info geoHelper', 9);
      console.log('Geolocation is supported!');
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed);
    } else {
      geoAlternative();
    }
    return true;
  };

  geoFailed = function(error) {
    $.doTimeout('GeoPermissionTimer', false);
    console.log(error.message);
    geoAlternative();
    return true;
  };

  geoSucceeded = function(position) {
    console.log('geo succeed');
    $('.geoHelper').remove();
    $.doTimeout('GeoPermissionTimer');
    geoHasPosition(position);
    return true;
  };

  geoWatch = function(position) {
    return geoHasPosition(position);
  };

  geoAlternative = function() {
    return $.getScript('http://j.maxmind.com/app/geoip.js', function(data, textStatus) {
      $('.geoHelper').remove();
      geoHasPosition({
        coords: {
          latitude: geoip_latitude(),
          longitude: geoip_longitude(),
          accuracy: -1
        }
      });
      return true;
    });
  };

  nj = new L.LatLng(40.058324, -74.405661);

  geoHasPosition = function(position) {
    var closest, distance, distanceToClosest, inOfficialCity, key, p, val;
    inOfficialCity = false;
    closest = '';
    distanceToClosest = 10000000000000000000000000000000;
    p = new L.LatLng(position.coords.latitude, position.coords.longitude);
    if (position.coords.accuracy > 2000 || position.coords.accuracy === -1) {
      console.log('varying');
      p = varyLatLng(p);
    }
    state.geoPos = p;
    for (key in officialCities) {
      if (!__hasProp.call(officialCities, key)) continue;
      val = officialCities[key];
      distance = p.distanceTo(val);
      if (distance < config.maxDistanceFromOfficial()) inOfficialCity = true;
      if (distance < distanceToClosest) {
        distanceToClosest = distance;
        closest = key;
      }
    }
    if (inOfficialCity) {
      map.setView(p, config.defZoom());
      window.centerCursor();
    } else {
      console.log('dang you arent in an official city');
      if (window.VARYLATLNG) {
        map.setView(varyLatLng(officialCities[closest]), config.defZoom());
      } else {
        map.setView(officialCities[closest], config.defZoom());
      }
      window.insertMessage("&quotHey, That's Not Where I Am!&quot", "Scribver.se is still in beta, so we're limiting ourselves to a few cities for now. We took you to <b>" + closest + "</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty.<br><br><a href='#' class='goToActualPos btn' data-dismiss='alert'>Click here to go to your location</a>", 'major alert-info', 25);
    }
    return true;
  };

  $('.cancelAltGeo').live('click', function() {
    return $.doTimeout('GeoPermissionTimer');
  });

  $('.goToActualPos').live('click', function() {
    map.setView(state.geoPos, config.defZoom());
    window.centerCursor();
    return true;
  });

  window.varyLatLng = function(l) {
    var latOffset, lngOffset, p;
    latOffset = Math.random() / 100;
    lngOffset = Math.random() / 100;
    if (Math.random() > 0.5) latOffset = 0 - latOffset;
    if (Math.random() > 0.5) lngOffset = 0 - lngOffset;
    p = new L.LatLng(l.lat + latOffset, l.lng + lngOffset);
    return p;
  };

}).call(this);
