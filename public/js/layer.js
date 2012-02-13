(function() {
  var betterBuildTile;

  window.buildTile = function(tile) {
    var c, cell, frag, r, _ref, _ref2;
    tile._cells = {};
    frag = document.createDocumentFragment();
    for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
        cell = Cell.getOrCreate(r, c, tile);
        frag.appendChild(cell.span);
      }
    }
    return frag;
  };

  betterBuildTile = function(tile, tileData, absTilePoint) {
    var c, cell, cellData, frag, r, _ref, _ref2, _ref3, _ref4;
    frag = document.createDocumentFragment();
    if (tileData) {
      for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
        for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
          cellData = tileData["" + (absTilePoint.x + c) + "x" + (absTilePoint.y + r)];
          if (cellData) {
            console.log('cell loaded from server');
            cell = new Cell(r, c, tile, cellData.contents);
            frag.appendChild(cell.span);
          }
        }
      }
    } else {
      for (r = 0, _ref3 = state.numRows() - 1; 0 <= _ref3 ? r <= _ref3 : r >= _ref3; 0 <= _ref3 ? r++ : r--) {
        for (c = 0, _ref4 = state.numCols() - 1; 0 <= _ref4 ? c <= _ref4 : c >= _ref4; 0 <= _ref4 ? c++ : c--) {
          cell = Cell.getOrCreate(r, c, tile);
          frag.appendChild(cell.span);
          console.log('cell created');
        }
      }
    }
    return frag;
  };

  L.TileLayer.Dom = L.TileLayer.extend({
    initialize: function(options) {
      dbg('init!');
      L.Util.setOptions(this, options);
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
      tile = this._divProto.cloneNode(false);
      tile.onselectstart = tile.onmousemove = L.Util.falseFn;
      return tile;
    },
    _loadTile: function(tile, tilePoint, zoom) {
      var d, layer;
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
      layer = this;
      now.ready(function() {
        var absTilePoint;
        absTilePoint = {
          x: tilePoint.x * Math.pow(2, state.zoomDiff()),
          y: tilePoint.y * Math.pow(2, state.zoomDiff())
        };
        now.getTile(absTilePoint, state.numRows());
        return now.gotTile = function(tileData, atp) {
          var frag;
          frag = betterBuildTile(tile, tileData, atp);
          return layer.drawTile(tile, tilePoint, zoom, frag);
        };
      });
      return true;
    },
    drawTile: function(tile, tilePoint, zoom, frag) {
      console.log(tilePoint);
      tile.appendChild(frag);
      console.log('drawtile', tile);
      return true;
    },
    _getTile: function() {
      dbg('_getTile called');
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
