(function() {

  L.TileLayer.Dom = L.TileLayer.extend({
    options: {
      async: false
    },
    initialize: function(options) {
      console.log('init!');
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
      var cell, i, tileSize;
      console.log('creatingTileProto');
      this._divProto = L.DomUtil.create('div', 'leaflet-tile');
      tileSize = this.options.tileSize;
      this._divProto.style.width = tileSize + 'px';
      this._divProto.style.height = tileSize + 'px';
      this._docFragment = document.createDocumentFragment();
      for (i = 1; i <= 30; i++) {
        cell = this._docFragment.appendChild(document.createElement("span"));
        cell.innerHTML = 'A';
      }
      return true;
    },
    _createTile: function() {
      var tile;
      console.log('_createTile called');
      tile = this._divProto.cloneNode(true);
      tile.appendChild(this._docFragment.cloneNode(true));
      tile.onselectstart = tile.onmousemove = L.Util.falseFn;
      return tile;
    },
    _loadTile: function(tile, tilePoint, zoom) {
      console.log('_loadTile called');
      tile._layer = this;
      tile._tilePoint = tilePoint;
      tile._zoom = zoom;
      this.drawTile(tile, tilePoint, zoom);
      if (!this.options.async) this.tileDrawn(tile);
      return true;
    },
    drawTile: function(tile, tilePoint, zoom) {
      return true;
    },
    _getTile: function() {
      var tile;
      console.log('_getTile called');
      if (this.options.reuseTiles && this._unusedTiles.length > 0) {
        tile = this._unusedTiles.pop();
        this._resetTile(tile);
        return tile;
      }
      return this._createTile();
    },
    tileDrawn: function(tile) {
      console.log('tileDrawn called');
      return this._tileOnLoad.call(tile);
    },
    _tileOnLoad: function(e) {
      var layer;
      console.log('_tileOnLoad called');
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

}).call(this);
