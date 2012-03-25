(function() {
  var Configuration;

  window.DEBUG = false;

  window.USEMAP = false;

  window.addEventListener("load", function() {
    return setTimeout(function() {
      console.log('trying to scroll yo');
      return window.scrollTo(0, 0);
    }, 0);
  });

  window.Configuration = Configuration = (function() {

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
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : " ";
      };
      this.inputRateLimit = function() {
        var _ref;
        return (_ref = spec.inputRateLimit) != null ? _ref : 40;
      };
    }

    return Configuration;

  })();

  window.config = new Configuration;

}).call(this);
