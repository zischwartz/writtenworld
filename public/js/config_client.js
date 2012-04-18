(function() {
  var Configuration, userLevels;

  window.DEBUG = false;

  window.USEMAP = true;

  window.VARYLATLNG = false;

  window.GOOGANAL = false;

  Configuration = Configuration = (function() {

    function Configuration(spec) {
      var _ref;
      if (spec == null) spec = {};
      this.tileSize = function() {
        var _ref;
        return (_ref = spec.tileSize) != null ? _ref : {
          x: 192,
          y: 256
        };
      };
      this.maxZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 20;
      };
      this.minZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 16;
      };
      this.defZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 17;
      };
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : " ";
      };
      this.inputRateLimit = function() {
        var _ref;
        return (_ref = spec.inputRateLimit) != null ? _ref : 40;
      };
      this.maxDistanceFromOfficial = function() {
        var _ref;
        return (_ref = spec.maxDistanceFromOfficial) != null ? _ref : 10000;
      };
      this.maxJumpDistance = (_ref = spec.maxJumpDistance) != null ? _ref : 0;
    }

    return Configuration;

  })();

  window.config = new Configuration;

  window.officialCities = {
    'New York City': new L.LatLng(40.73037270272987, -73.99361729621887),
    'Washington DC': new L.LatLng(38.898715, -77.037655)
  };

  userLevels = {
    0: {
      showLotsOfAnimations: false,
      colorsAvailable: ['c0', 'c1', 'c2', 'c3']
    }
  };

  window.prefs = {
    animate: {
      ever: true,
      writing: false
    }
  };

}).call(this);
