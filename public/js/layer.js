(function() {
  var betterBuildTile, getTileLocally;

  betterBuildTile = function(tile, tileData, absTilePoint) {
    var c, cell, cellData, frag, r, _ref, _ref2;
    tile._cells = [];
    frag = document.createDocumentFragment();
    for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
        cellData = tileData["" + (absTilePoint.x + c) + "x" + (absTilePoint.y + r)];
        if (cellData) {
          dbg('cell loaded from server');
          dbg('cellData', cellData.contents);
          cell = Cell.getOrCreate(r, c, tile, cellData.contents, cellData.props);
        } else {
          cell = Cell.getOrCreate(r, c, tile);
          dbg('cell created, but others in tile were from server');
        }
        frag.appendChild(cell.span);
        tile._cells.push(cell);
      }
    }
    return frag;
  };

  getTileLocally = function(absTilePoint, tile) {
    var c, cell, cellsNeeded, frag, r, _ref, _ref2;
    console.log('getting locally');
    tile._cells = [];
    frag = document.createDocumentFragment();
    cellsNeeded = state.numRows() * state.numCols();
    for (r = 0, _ref = state.numRows() - 1; 0 <= _ref ? r <= _ref : r >= _ref; 0 <= _ref ? r++ : r--) {
      for (c = 0, _ref2 = state.numCols() - 1; 0 <= _ref2 ? c <= _ref2 : c >= _ref2; 0 <= _ref2 ? c++ : c--) {
        cell = Cell.get(absTilePoint.x + c, absTilePoint.y + r);
        if (cell) {
          cell = Cell.getOrCreate(r, c, tile);
          frag.appendChild(cell.span);
          dbg('FOUND CELL--------', cell);
          cellsNeeded--;
          tile._cells.push(cell);
        }
      }
    }
    if (cellsNeeded <= 0) {
      dbg('we have the entire tile');
      return frag;
    } else {
      tile._cells = null;
      return false;
    }
  };

  L.TileLayer.Dom = L.TileLayer.extend({
    options: {
      unloadInvisibleTiles: true
    },
    initialize: function(options) {
      dbg('init!');
      L.Util.setOptions(this, options);
      this.on('tileunload', function(e) {
        return this._onTileUnload(e);
      });
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
      var absTilePoint, d, frag, layer;
      dbg('_loadTile called');
      tile._layer = this;
      tile._tilePoint = tilePoint;
      tile._zoom = zoom;
      tile.onload = this._tileOnLoad;
      tile.onerror = this._tileOnError;
      if (DEBUG) {
        d = document.createElement('div');
        d.className = 'debug';
        d.innerHTML = tilePoint + ' ' + zoom;
        tile.appendChild(d);
        $(tile).addClass('debugTile');
      }
      layer = this;
      absTilePoint = {
        x: tilePoint.x * Math.pow(2, state.zoomDiff()),
        y: tilePoint.y * Math.pow(2, state.zoomDiff())
      };
      frag = getTileLocally(absTilePoint, tile);
      if (frag) {
        layer.drawTile(tile, tilePoint, zoom, frag);
        layer.tileDrawn(tile);
      } else {
        now.getTile(absTilePoint, state.numRows(), function(tileData, atp) {
          frag = betterBuildTile(tile, tileData, atp);
          layer.drawTile(tile, tilePoint, zoom, frag);
          return layer.tileDrawn(tile);
        });
      }
      return true;
    },
    drawTile: function(tile, tilePoint, zoom, frag) {
      tile.appendChild(frag);
      return true;
    },
    _getTile: function() {
      dbg('_getTile called');
      return this._createTile();
    },
    tileDrawn: function(tile) {
      dbg('tileDrawn called');
      tile.className += ' leaflet-tile-drawn';
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
    _onTileUnload: function(e) {
      var c, _i, _len, _ref, _results;
      if (e.tile._zoom === map.getZoom()) {
        dbg('unload due to pan, easy');
        _ref = e.tile._cells;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          _results.push(c.kill());
        }
        return _results;
      } else if (e.tile._zoom < map.getZoom()) {
        dbg('zoom in');
        return console.log('unload due to zoom, less easy');
      } else if (e.tile._zoom > map.getZoom()) {
        return dbg('zoom out');
      }
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
