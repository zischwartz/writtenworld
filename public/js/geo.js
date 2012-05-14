// Generated by CoffeeScript 1.3.1
(function() {
  var geoAlternative, geoFailed, geoHasPosition, geoSucceeded, geoWatch,
    __hasProp = {}.hasOwnProperty;

  window.initializeGeo = function() {
    var body;
    $.doTimeout('GeoPermissionTimer', 10 * 1000, function() {
      geoAlternative();
      return false;
    });
    if (navigator.geolocation) {
      body = "If your browser asks you to use location, please click <b> allow</b>. Otherwise, we'll try to find you based on your IP in a few seconds. <br> <a href='#' data-dismiss='alert' class='cancelAltGeo btn'>Or click here to stay right here</a>";
      window.insertMessage('Welcome', body, 'major alert-info geoHelper', 12);
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed);
    } else {
      geoAlternative();
    }
    return true;
  };

  geoFailed = function(error) {
    $.doTimeout('GeoPermissionTimer', false);
    geoAlternative();
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

  geoHasPosition = function(position) {
    var closest, distance, distanceToClosest, inOfficialCity, key, msgbody, p, val;
    inOfficialCity = false;
    closest = '';
    distanceToClosest = 10000000000000000000000000000000;
    p = new L.LatLng(position.coords.latitude, position.coords.longitude);
    state.geoPos = p;
    state.geoAccuracy = position.coords.accuracy;
    if (position.coords.accuracy > 2000 || position.coords.accuracy === -1) {
      p = varyLatLng(p);
    }
    state.geoPos = p;
    state.initialGeoPos = new L.LatLng(p.lat, p.lng);
    for (key in officialCities) {
      if (!__hasProp.call(officialCities, key)) continue;
      val = officialCities[key];
      distance = p.distanceTo(val);
      if (distance < config.maxDistanceFromOfficial()) {
        inOfficialCity = true;
      }
      if (distance < distanceToClosest) {
        distanceToClosest = distance;
        closest = key;
      }
    }
    if (inOfficialCity) {
      map.setView(p, config.defZoom());
      window.centerCursor();
    } else {
      if (window.VARYLATLNG) {
        map.setView(varyLatLng(officialCities[closest]), config.defZoom());
      } else {
        map.setView(officialCities[closest], config.defZoom());
      }
      msgbody = "Written World is in beta, so we're limited  a few cities for now. We took you to <b>" + closest + "</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty. <br><br><a href='#' class='goToActualPos btn btn-success' data-dismiss='alert'>Click here to go to your location</a> <a href='#' class= btn btn-primary' data-dismiss='alert'>Stay Here</a>";
      window.insertMessage("&quotHey, That's Not Where I Am!&quot", msgbody, 'major alert-info', 45);
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
    if (Math.random() > 0.5) {
      latOffset = 0 - latOffset;
    }
    if (Math.random() > 0.5) {
      lngOffset = 0 - lngOffset;
    }
    p = new L.LatLng(l.lat + latOffset, l.lng + lngOffset);
    return p;
  };

}).call(this);
