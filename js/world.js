(function() {
  var Cell, Configuration, filter, getNodeIndex, initializeInterface, moveCursor, pan, panIfAppropriate, setTileStyle,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = Array.prototype.slice;

  window.DEBUG = false;

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
        return (_ref = spec.maxZoom) != null ? _ref : 18;
      };
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : " ";
      };
    }

    return Configuration;

  })();

  window.config = new Configuration;

  window.state = {
    selectedCell: null,
    lastClickCell: null,
    writeDirection: 'right',
    zoomDiff: function() {
      return config.maxZoom() - map.getZoom();
    },
    numRows: function() {
      var numRows;
      return numRows = Math.pow(2, state.zoomDiff());
    },
    numCols: function() {
      var numCols;
      return numCols = Math.pow(2, state.zoomDiff());
    },
    cellWidth: function() {
      return config.tileSize().x / state.numCols();
    },
    cellHeight: function() {
      return config.tileSize().y / state.numRows();
    }
  };

  setTileStyle = function() {
    var fontSize, height, rules, width;
    width = state.cellWidth();
    height = state.cellHeight();
    fontSize = height * 0.9;
    rules = [];
    rules.push("div.leaflet-tile span { width: " + width + "px; height: " + height + "px; font-size: " + fontSize + "px;}");
    return $("#dynamicStyles").text(rules.join("\n"));
  };

  window.setSelected = function(cell) {
    dbg('selecting', cell);
    if (state.selectedEl) $(state.selectedEl).removeClass('selected');
    state.selectedEl = cell.span;
    $(cell.span).addClass('selected');
    state.selectedCell = cell;
    return true;
  };

  moveCursor = function(direction, from) {
    var key, target, targetCell, _ref;
    if (from == null) from = state.selectedCell;
    dbg('move cursor');
    target = {};
    _ref = from.key.slice(1).split('x'), target.x = _ref[0], target.y = _ref[1];
    target.x = parseInt(target.x, 10);
    target.y = parseInt(target.y, 10);
    switch (direction) {
      case 'up':
        target.y = target.y - 1;
        break;
      case 'down':
        target.y = target.y + 1;
        break;
      case 'left':
        target.x = target.x - 1;
        break;
      case 'right':
        target.x = target.x + 1;
    }
    key = "c" + target.x + "x" + target.y;
    targetCell = Cell.all()[key];
    setSelected(targetCell);
    return true;
  };

  initializeInterface = function() {
    $("#map").click(function(e) {
      var cell;
      if ($(e.target).hasClass('cell')) {
        cell = Cell.all()[e.target.id];
        state.lastClickCell = cell;
        setSelected(cell);
        return inputEl.focus();
      } else {
        inputEl.focus();
        return false;
      }
    });
    window.inputEl = $("#input");
    inputEl.focus();
    map.on('zoomend', function() {
      return inputEl.focus();
    });
    inputEl.keypress(function(e) {
      var c;
      console.log(e.which, 'pressed');
      if (e.which === 13) {
        moveCursor('down', state.lastClickCell);
        panIfAppropriate('down');
        return state.lastClickCell = state.selectedCell;
      } else {
        c = String.fromCharCode(e.which);
        dbg(c, 'PRESSED!!!!');
        state.selectedCell.write(c);
        moveCursor(state.writeDirection);
        return panIfAppropriate(state.writeDirection);
      }
    });
    return inputEl.keydown(function(e) {
      console.log(e, e.which, ' keydownd');
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          moveCursor('up');
          return panIfAppropriate('up');
        case 40:
          moveCursor('down');
          return panIfAppropriate('down');
        case 39:
          moveCursor('right');
          return panIfAppropriate('right');
        case 37:
          moveCursor('left');
          return panIfAppropriate('left');
        case 8:
          moveCursor('left');
          panIfAppropriate('left');
          return state.selectedCell.write(' ');
      }
    });
  };

  panIfAppropriate = function(direction) {
    var panByDist, panOnDist, selectedPP;
    selectedPP = $(state.selectedEl).offset();
    panOnDist = 200;
    panByDist = state.cellHeight();
    if (direction === 'up') if (selectedPP.top < panOnDist) pan(0, 0 - panByDist);
    if (direction === 'down') {
      if (selectedPP.top > document.height - panOnDist * 1.5) pan(0, panByDist);
    }
    if (direction === 'right') {
      if (selectedPP.left > document.width - panOnDist) pan(panByDist, 0);
    }
    if (direction === 'left') {
      if (selectedPP.left < panOnDist) return pan(0 - panByDist, 0);
    }
  };

  jQuery(function() {
    var testMarker, tileServeLayer, tileServeUrl;
    tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png';
    tileServeLayer = new L.TileLayer(tileServeUrl, {
      maxZoom: config.maxZoom()
    });
    window.map = new L.Map('map', {
      center: new L.LatLng(51.505, -0.09),
      zoom: 16,
      scrollWheelZoom: false
    }).addLayer(tileServeLayer);
    window.domTiles = new L.TileLayer.Dom({
      tileSize: config.tileSize()
    });
    testMarker = new L.Marker(map.getCenter());
    map.addLayer(testMarker);
    testMarker.on('click', function(e) {
      return console.log(e);
    });
    map.addLayer(domTiles);
    setTileStyle();
    map.on('zoomend', function() {
      return setTileStyle();
    });
    initializeInterface();
    return true;
  });

  window.Cell = Cell = (function() {
    var all;

    all = {};

    Cell.all = function() {
      return all;
    };

    Cell.prototype.generateKey = function() {
      var x, y;
      x = this.tile._tilePoint.x * Math.pow(2, state.zoomDiff());
      y = this.tile._tilePoint.y * Math.pow(2, state.zoomDiff());
      x += this.col;
      y += this.row;
      return "c" + x + "x" + y;
    };

    function Cell(row, col, tile, contents, properties, events) {
      this.row = row;
      this.col = col;
      this.tile = tile;
      this.contents = contents != null ? contents : config.defaultChar();
      this.properties = properties != null ? properties : null;
      this.events = events != null ? events : null;
      this.generateKey = __bind(this.generateKey, this);
      this.history = {};
      this.timestamp = null;
      this.key = this.generateKey();
      all[this.key] = this;
      this.span = document.createElement('span');
      this.span.innerHTML = config.defaultChar();
      this.span.id = this.key;
      this.span.className = 'cell';
    }

    Cell.prototype.write = function(c) {
      this.contents = c;
      return this.span.innerHTML = c;
    };

    return Cell;

  })();

  pan = function(x, y) {
    var p;
    p = new L.Point(x, y);
    map.panBy(p);
    return map;
  };

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

  window.dbg = function() {
    var message, more;
    message = arguments[0], more = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    if (DEBUG) {
      console.log(message);
      return true;
    }
    if (DEBUG && more) {
      console.log(message, more);
      return true;
    }
    return true;
  };

}).call(this);
