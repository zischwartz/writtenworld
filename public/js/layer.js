(function() {

  window.buildTile = function(tile) {
    var c, cell, frag, r, _ref, _ref2;
    tile._cells = {};
    frag = document.createDocumentFragment();
    for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
        cell = new Cell(r, c, tile);
        frag.appendChild(cell.span);
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
      var d;
      dbg('_loadTile called');
      tile._layer = this;
      tile._tilePoint = tilePoint;
      tile._zoom = zoom;
      if (DEBUG) {
        d = document.createElement('div');
        d.className = 'debug';
        d.innerHTML = tilePoint + ' ' + zoom;
        tile.appendChild(d);
        $(tile).addClass('debugTile');
      }
      this.drawTile(tile, tilePoint, zoom);
      if (!this.options.async) this.tileDrawn(tile);
      return true;
    },
    drawTile: function(tile, tilePoint, zoom) {
      var content;
      content = buildTile(tile);
      tile.appendChild(content);
      console.log('drawtile');
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
    },
    getTilePointBounds: function() {
      var bounds, nwTilePoint, seTilePoint, tileBounds, tileSize;
      bounds = this._map.getPixelBounds();
      tileSize = this.options.tileSize;
      nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x), Math.floor(bounds.min.y / tileSize.y));
      seTilePoint = new L.Point(Math.floor(bounds.max.x / tileSize.x), Math.floor(bounds.max.y / tileSize.y));
      tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
      return tileBounds;
    },
    getTilePointAbsoluteBounds: function() {
      var bounds, nwTilePoint, offset, seTilePoint, tileBounds, tileSize;
      bounds = this._map.getPixelBounds();
      tileSize = this.options.tileSize;
      offset = Math.pow(2, state.zoomDiff());
      nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x) * offset, Math.floor(bounds.min.y / tileSize.y) * offset);
      seTilePoint = new L.Point(Math.floor(bounds.max.x / tileSize.x) * offset, Math.floor(bounds.max.y / tileSize.y) * offset);
      tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
      return tileBounds;
    }
  });

}).call(this);
