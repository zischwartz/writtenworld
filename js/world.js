(function() {
  var Configuration, buildTile, filter, geoAlternative, geoFailed, geoHasPosition, geoSucceeded, geoWatch, getNodeIndex, initializeGeo, initializeInterface, moveCursor, setSelected;

  window.Configuration = Configuration = (function() {

    function Configuration(spec) {
      if (spec == null) spec = {};
      this.tileSize = function() {
        var _ref;
        return (_ref = spec.tileSize) != null ? _ref : 256;
      };
      this.maxZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 18;
      };
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : ".";
      };
    }

    return Configuration;

  })();

  window.config = new Configuration;

  window.state = {
    selectedEl: null,
    selectedTileKey: null,
    selectedCellKey: null,
    geoInitialPos: null,
    geoCurrentPos: null,
    geoAccuracy: null,
    writeDirection: 'right',
    zoomDiff: function() {
      return config.maxZoom() - map.zoom() + 1;
    },
    numRows: function() {
      var numRows;
      return numRows = Math.pow(2, state.zoomDiff());
    },
    numCols: function() {
      var numCols;
      return numCols = Math.pow(2, state.zoomDiff()) * 2;
    }
  };

  setSelected = function(el) {
    if (state.selectedEl) state.selectedEl.className.baseVal = '';
    state.selectedEl = el;
    el.className.baseVal = 'selected';
    state.selectedTileKey = el.tileKey;
    state.selectedCellKey = el.cellKey;
    return true;
  };

  moveCursor = function(direction, from) {
    var target, zoom, _ref, _ref2;
    if (from == null) from = state.selected;
    console.log('from', from);
    console.log(direction);
    target = {};
    _ref = state.selectedCellKey.split('/'), target.col = _ref[0], target.row = _ref[1];
    _ref2 = state.selectedTileKey.split('/'), zoom = _ref2[0], target.lat = _ref2[1], target.lng = _ref2[2];
    switch (direction) {
      case 'up':
        target.row = target.row - 1;
        break;
      case 'down':
        target.row = target.row + 1;
        break;
      case 'left':
        target.col = target.col - 1;
        break;
      case 'right':
        target.col = target.col + 1;
    }
    if (target.row < 0) {
      target.lng = target.lng - 1;
      target.row = state.numRows() - 1;
    }
    if (target.row >= state.numRows()) {
      target.lng = target.lng + 1;
      target.row = 0;
    }
    if (target.col < 0) {
      target.lat = target.lat - 1;
      target.col = state.numCols() - 1;
    }
    if (target.col >= state.numCols()) {
      target.lat = target.lat + 1;
      target.col = 0;
    }
    setSelected(el);
    return true;
  };

  initializeInterface = function() {
    var inputEl;
    inputEl = $("#input");
    inputEl.focus();
    inputEl.keypress(function(e) {
      var c;
      c = String.fromCharCode(e.which);
      console.log(c, 'PRESSED!!!!');
      state.lastChar = c;
      state.selectedTile.write(state.selectedRC, c);
      return moveCursor(state.writeDirection);
    });
    return inputEl.keydown(function(e) {
      var isNearEdge, panOnDist, selectedPP;
      isNearEdge = false;
      selectedPP = $(state.selectedEl).offset();
      panOnDist = 150;
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          moveCursor('up');
          if (selectedPP.top < panOnDist) return map.panBy(0, -30);
          break;
        case 40:
          moveCursor('down');
          if (selectedPP.top > document.height - panOnDist) {
            return map.panBy(0, 30);
          }
          break;
        case 39:
          moveCursor('right');
          if (selectedPP.left > document.width - panOnDist) {
            return map.panBy(30, 0);
          }
          break;
        case 37:
          moveCursor('left');
          if (selectedPP.left < panOnDist) return map.panBy(-30, 0);
      }
    });
  };

  initializeGeo = function() {
    if (navigator.geolocation) {
      console.log('Geolocation is supported!');
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed);
    } else {
      console.log('Geolocation is not supported for this Browser/OS version yet.');
      geoAlternative();
    }
    return true;
  };

  geoFailed = function(error) {
    geoAlternative();
    console.log(error.message);
    return true;
  };

  geoSucceeded = function(position) {
    geoHasPosition(position);
    state.geoInitialPos = position;
    console.log(position);
    return true;
  };

  geoWatch = function(position) {
    geoHasPosition(position);
    return console.log('Moved position, or just the initial');
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

  geoHasPosition = function(position) {
    state.geoCurrentPos = position;
    map.center({
      lat: position.coords.latitude,
      lon: position.coords.longitude
    });
    console.log('we have the position');
    return true;
  };

  jQuery(function() {
    var tileServeLayer, tileServeUrl;
    tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png';
    tileServeLayer = new L.TileLayer(tileServeUrl, {
      maxZoom: config.maxZoom()
    });
    window.map = new L.Map('map', {
      center: new L.LatLng(51.505, -0.09),
      zoom: 16
    }).addLayer(tileServeLayer);
    window.domTiles = new L.TileLayer.Dom();
    domTiles.drawTiles = function(tile, tilePoint, zoom) {
      console.log('draw');
      return true;
    };
    map.addLayer(domTiles);
    initializeInterface();
    return true;
  });

  buildTile = function() {
    var c, r, _ref, _results;
    _results = [];
    for (r = 0, _ref = state.numRows(); 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      _results.push((function() {
        var _ref2, _results2;
        _results2 = [];
        for (c = 0, _ref2 = state.numCols(); 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
          cell.setAttribute("y", cellHeight * r);
          cell.setAttribute("x", cellWidth * c);
          cell.setAttribute("font-size", cellWidth);
          cell.textContent = config.defaultChar();
          cell.tileKey = tile.key;
          _results2.push(cell.cellKey = c + '/' + r);
        }
        return _results2;
      })());
    }
    return _results;
  };

  true;

  filter = function(list, func) {
    var x, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = list.length; _i < _len; _i++) {
      x = list[_i];
      if (func(x)) _results.push(x);
    }
    return _results;
  };

  Array.prototype.remove = function(e) {
    var t, _ref;
    if ((t = this.indexOf(e)) > -1) {
      return ([].splice.apply(this, [t, t - t + 1].concat(_ref = [])), _ref);
    }
  };

  getNodeIndex = function(node) {
    return $(node).parent().children().index(node);
  };

}).call(this);
