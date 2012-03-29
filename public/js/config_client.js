(function() {
  var Configuration;

  window.DEBUG = false;

  window.USEMAP = true;

  Configuration = Configuration = (function() {

    function Configuration(spec) {
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
    }

    return Configuration;

  })();

  window.config = new Configuration;

  window.officialCities = {
    'New York City': new L.LatLng(40.714269, -74.005972),
    'Washington DC': new L.LatLng(38.898715, -77.037655)
  };

}).call(this);
