// Generated by CoffeeScript 1.3.1
(function() {
  var Configuration, mapBoxUrl, s3Url, tileServeUrl;

  window.DEBUG = false;

  window.USEMAP = true;

  window.VARYLATLNG = false;

  window.MapBoxBadZoomOffset = 2;

  s3Url = "http://s3.amazonaws.com/ww-tiles/wwtiles/{z}/{x}/{y}.png";

  mapBoxUrl = "http://{s}.tiles.mapbox.com/v3/zischwartz.map-ei57zypj/{z}/{x}/{y}.png";

  tileServeUrl = "http://23.23.200.225/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png";

  Configuration = Configuration = (function() {

    Configuration.name = 'Configuration';

    function Configuration(spec) {
      var _ref;
      if (spec == null) {
        spec = {};
      }
      this.tileSize = function() {
        var _ref;
        return (_ref = spec.tileSize) != null ? _ref : {
          x: 192,
          y: 256
        };
      };
      this.tileServeUrl = function() {
        var _ref;
        return (_ref = spec.tileServeUrl) != null ? _ref : tileServeUrl;
      };
      this.maxZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 20;
      };
      this.minZoom = function() {
        var _ref;
        return (_ref = spec.minZoom) != null ? _ref : 15;
      };
      this.defZoom = function() {
        var _ref;
        return (_ref = spec.defZoom) != null ? _ref : 17;
      };
      this.minLayerZoom = function() {
        var _ref;
        return (_ref = spec.minLayerZoom) != null ? _ref : 16;
      };
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : " ";
      };
      this.inputRateLimit = function() {
        var _ref;
        return (_ref = spec.inputRateLimit) != null ? _ref : 20;
      };
      this.maxDistanceFromOfficial = function() {
        var _ref;
        return (_ref = spec.maxDistanceFromOfficial) != null ? _ref : 10000;
      };
      this.maxJumpDistance = (_ref = spec.maxJumpDistance) != null ? _ref : 0;
    }

    return Configuration;

  })();

  window.config = new Configuration(window.worldSpec);

  window.officialCities = {
    'New York City': new L.LatLng(40.73037270272987, -73.99361729621887)
  };

}).call(this);
