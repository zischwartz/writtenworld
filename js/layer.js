(function() {

  window.buildTile = function() {
    var c, cell, frag, r, _ref, _ref2;
    frag = document.createDocumentFragment();
    for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
        cell = new L.Cell();
        cell.element = frag.appendChild(document.createElement('span'));
        cell.innerHTML = config.defaultChar();
      }
    }
    return frag;
  };

  L.TileLayer.Dom = L.TileLayer.extend({
    options: {
      async: false
    },
    initialize: function(options) {
      dbg('init!');
      L.Util.setOptions(this, options);
      return true;
    },
    redraw: function() {
      var i, tile, _i, _len, _ref, _results;
      _ref = this._tiles;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        tile = this._tiles[i];
        this._redrawTile(tile);
        _results.push(true);
      }
      return _results;
    },
    _redrawTile: function(tile) {
      this.drawTile(tile, tile._tilePoint, tile._zoom);
      return true;
    },
    _createTileProto: function() {
      var tileSize;
      dbg('creatingTileProto');
      this._divProto = L.DomUtil.create('div', 'leaflet-tile');
      tileSize = this.options.tileSize;
      this._divProto.style.width = tileSize.x + 'px';
      this._divProto.style.height = tileSize.y + 'px';
      return true;
    },
    _createTile: function() {
      var tile;
      dbg('_createTile called');
      tile = this._divProto.cloneNode(false);
      tile.onselectstart = tile.onmousemove = L.Util.falseFn;
      return tile;
    },
    _loadTile: function(tile, tilePoint, zoom) {
      dbg('_loadTile called');
      tile._layer = this;
      tile._tilePoint = tilePoint;
      tile._zoom = zoom;
      this.drawTile(tile, tilePoint, zoom);
      if (!this.options.async) this.tileDrawn(tile);
      return true;
    },
    drawTile: function(tile, tilePoint, zoom) {
      var content;
      content = buildTile();
      tile.appendChild(content.cloneNode(true));
      dbg('drawTile called, does nothing');
      return true;
    },
    _getTile: function() {
      var tile;
      dbg('_getTile called');
      if (this.options.reuseTiles && this._unusedTiles.length > 0) {
        tile = this._unusedTiles.pop();
        this._resetTile(tile);
        return tile;
      }
      return this._createTile();
    },
    tileDrawn: function(tile) {
      dbg('tileDrawn called');
      return this._tileOnLoad.call(tile);
    },
    _tileOnLoad: function(e) {
      var layer;
      dbg('_tileOnLoad called');
      layer = this._layer;
      this.className += ' leaflet-tile-loaded';
      layer.fire('tileload', {
        tile: this,
        url: this.src
      });
      layer._tilesToLoad--;
      if (!layer._tilesToLoad) layer.fire('load');
      return true;
    }
  });

  L.Cell = L.Class.extend({
    includes: L.Mixin.Events,
    awesome: 'abcdefghijkl',
    options: {
      clickable: true,
      draggable: false
    },
    initialize: function(tile, row, col, options) {
      L.Util.setOptions(this, options);
      this.tile = tile;
      this.row = row;
      this.col = col;
      return true;
    },
    addToTile: function() {
      return true;
    }
  });

}).call(this);
