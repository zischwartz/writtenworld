(function() {
  var chicago, geoAlternative, geoFailed, geoHasPosition, geoSucceeded, geoWatch, nj,
    __hasProp = Object.prototype.hasOwnProperty;

  window.initializeGeo = function() {
    $.doTimeout('GeoPermissionTimer', 10 * 1000, function() {
      console.log('User did not respond for a while, switching to alt');
      geoAlternative();
      return false;
    });
    if (navigator.geolocation) {
      window.insertMessage('Welcome', "If your browser asks you if it's ok to use location, please click <b> allow</b>. Otherwise, we'll try to find you based on your IP in a few seconds. <br> <a href='#' class='cancelAltGeo btn'>Or click here to stay right here</a>", 'major alert-info geoHelper', 9);
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed);
    } else {
      geoAlternative();
    }
    return true;
  };

  geoFailed = function(error) {
    $.doTimeout('GeoPermissionTimer', false);
    return true;
  };

  geoSucceeded = function(position) {
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

  chicago = new L.LatLng(41.878114, -87.629798);

  nj = new L.LatLng(40.058324, -74.405661);

  geoHasPosition = function(position) {
    var closest, distance, distanceToClosest, inOfficialCity, key, p, val;
    inOfficialCity = false;
    closest = '';
    distanceToClosest = 10000000000000000000000000000000;
    p = new L.LatLng(position.coords.latitude, position.coords.longitude);
    state.geoCurrentPos = p;
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
      map.setView(officialCities[closest], config.defZoom());
      window.insertMessage("&quotHey, That's Not Where I Am!&quot", "Scribver.se is still in beta, so we're limiting ourselves to a few cities for now. We took you to <b>" + closest + "</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty.<br><br><a href='#' class='goToActualPos btn' data-dismiss='alert'>Click here to go to your location</a>", 'major alert-info', 25);
    }
    return true;
  };

  $('.cancelAltGeo').live('click', function() {
    return $.doTimeout('GeoPermissionTimer');
  });

  $('.goToActualPos').live('click', function() {
    map.setView(state.geoCurrentPos, config.defZoom());
    return window.centerCursor();
  });

}).call(this);
