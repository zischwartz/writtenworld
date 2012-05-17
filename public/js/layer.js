// Generated by CoffeeScript 1.3.1
(function() {
  var betterBuildTile, getTileLocally;

  L.WCanvas = L.TileLayer.extend({
    options: {
      async: false
    },
    initialize: function(options) {
      return L.Util.setOptions(this, options);
    },
    redraw: function() {
      var i, tiles, _results;
      tiles = this._tiles;
      _results = [];
      for (i in tiles) {
        if (tiles.hasOwnProperty(i)) {
          _results.push(this._redrawTile(tiles[i]));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    },
    _redrawTile: function(tile) {
      return this.drawTile(tile, tile._tilePoint, tile._zoom);
    },
    _createTileProto: function() {
      var proto, tileSize;
      proto = this._canvasProto = L.DomUtil.create("canvas", "leaflet-tile");
      tileSize = this.options.tileSize;
      proto.width = tileSize.x;
      return proto.height = tileSize.y;
    },
    _createTile: function() {
      var tile;
      tile = this._canvasProto.cloneNode(false);
      tile.onselectstart = tile.onmousemove = L.Util.falseFn;
      return tile;
    },
    _loadTile: function(tile, tilePoint, zoom) {
      var absTilePoint,
        _this = this;
      tile._layer = this;
      tile._tilePoint = tilePoint;
      tile._zoom = zoom;
      absTilePoint = {
        x: tilePoint.x * Math.pow(2, state.zoomDiff()),
        y: tilePoint.y * Math.pow(2, state.zoomDiff())
      };
      return now.getZoomedOutTile(absTilePoint, state.numRows(), state.numCols(), function(tileData, atp) {
        _this.drawTile(tile, tilePoint, zoom, tileData.density);
        if (!_this.options.async) {
          return _this.tileDrawn(tile);
        }
      });
    },
    drawTile: function(tile, tilePoint, zoom, density) {
      var ctx, offset, radius;
      if (!density) {
        return;
      }
      offset = config.minLayerZoom() - zoom;
      radius = density * offset * 128;
      if (radius > 96) {
        radius = 96;
      }
      ctx = tile.getContext('2d');
      ctx.fillStyle = "rgba(195, 255, 195, 0.4 )";
      ctx.beginPath();
      ctx.arc(96, 128, radius, 0, Math.PI * 2, true);
      ctx.closePath();
      ctx.fill();
    },
    tileDrawn: function(tile) {
      return this._tileOnLoad.call(tile);
    },
    getTilePointAbsoluteBounds: function() {
      var bounds, nwTilePoint, offset, seTilePoint, tileBounds, tileSize;
      ({
        getTilePointAbsoluteBounds: function() {}
      });
      if (this._map) {
        bounds = this._map.getPixelBounds();
        tileSize = this.options.tileSize;
        offset = Math.pow(2, state.zoomDiff());
        nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x) * offset, Math.floor(bounds.min.y / tileSize.y) * offset);
        seTilePoint = new L.Point(Math.ceil(bounds.max.x / tileSize.x) * offset, Math.ceil(bounds.max.y / tileSize.y) * offset);
        tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
        return tileBounds;
      } else {
        return false;
      }
    },
    getCenterTile: function() {
      var bounds, center;
      bounds = this.getTilePointAbsoluteBounds();
      if (bounds) {
        center = bounds.getCenter();
        return center;
      } else {
        return false;
      }
    }
  });

  betterBuildTile = function(tile, tileData, absTilePoint) {
    var c, cell, cellData, frag, r, _i, _j, _ref, _ref1;
    tile._cells = [];
    frag = document.createDocumentFragment();
    for (r = _i = 0, _ref = state.numRows() - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; r = 0 <= _ref ? ++_i : --_i) {
      for (c = _j = 0, _ref1 = state.numCols() - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; c = 0 <= _ref1 ? ++_j : --_j) {
        cellData = tileData["" + (absTilePoint.x + c) + "x" + (absTilePoint.y + r)];
        if (cellData) {
          cell = Cell.getOrCreate(r, c, tile, cellData.contents, cellData.props);
        } else {
          cell = Cell.getOrCreate(r, c, tile);
        }
        frag.appendChild(cell.span);
        tile._cells.push(cell);
      }
    }
    return frag;
  };

  getTileLocally = function(absTilePoint, tile) {
    var c, cell, cellsNeeded, frag, r, _i, _j, _ref, _ref1;
    tile._cells = [];
    frag = document.createDocumentFragment();
    cellsNeeded = state.numRows() * state.numCols();
    for (r = _i = 0, _ref = state.numRows() - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; r = 0 <= _ref ? ++_i : --_i) {
      for (c = _j = 0, _ref1 = state.numCols() - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; c = 0 <= _ref1 ? ++_j : --_j) {
        cell = Cell.get(absTilePoint.x + c, absTilePoint.y + r);
        if (cell) {
          cell = Cell.getOrCreate(r, c, tile);
          frag.appendChild(cell.span);
          cellsNeeded--;
          tile._cells.push(cell);
        }
      }
    }
    if (cellsNeeded <= 0) {
      return frag;
    } else {
      tile._cells = null;
      return false;
    }
  };

  L.DomTileLayer = L.Class.extend({
    includes: L.Mixin.Events,
    options: {
      minZoom: config.minLayerZoom() - 1,
      maxZoom: config.maxZoom(),
      tileSize: {
        x: 256,
        y: 256
      },
      subdomains: "abc",
      errorTileUrl: "",
      attribution: "",
      opacity: 1,
      scheme: "xyz",
      continuousWorld: false,
      noWrap: false,
      zoomOffset: 0,
      zoomReverse: false,
      unloadInvisibleTiles: true,
      updateWhenIdle: config.updateWhenIdle(),
      reuseTiles: false
    },
    initialize: function(options, urlParams) {
      var subdomains;
      if (typeof this.options.tileSize === "number") {
        this.options.tileSize = {
          x: this.options.tileSize,
          y: this.options.tileSize
        };
      }
      L.Util.setOptions(this, options);
      this.on('tileunload', function(e) {
        return this._onTileUnload(e);
      });
      subdomains = this.options.subdomains;
      if (typeof subdomains === "string") {
        this.options.subdomains = subdomains.split("");
      }
      return true;
    },
    onAdd: function(map, insertAtTheBottom) {
      this._map = map;
      this._insertAtTheBottom = insertAtTheBottom;
      this._initContainer();
      this._createTileProto();
      map.on("viewreset", this._resetCallback, this);
      map.on("moveend", this._update, this);
      if (!this.options.updateWhenIdle) {
        this._limitedUpdate = L.Util.limitExecByInterval(this._update, 150, this);
        map.on("move", this._limitedUpdate, this);
      }
      this._reset();
      this._update();
    },
    onRemove: function(map) {
      console.log('onRemove called');
      map._panes.tilePane.removeChild(this._container);
      map.off("viewreset", this._resetCallback, this);
      map.off("moveend", this._update, this);
      if (!this.options.updateWhenIdle) {
        map.off("move", this._limitedUpdate, this);
      }
      this._container = null;
      this._map = null;
      return true;
    },
    getAttribution: function() {
      return this.options.attribution;
    },
    setOpacity: function(opacity) {
      var i, tiles;
      this.options.opacity = opacity;
      if (this._map) {
        this._updateOpacity();
      }
      i = void 0;
      tiles = this._tiles;
      if (L.Browser.webkit) {
        for (i in tiles) {
          if (tiles.hasOwnProperty(i)) {
            tiles[i].style.webkitTransform += " translate(0,0)";
          }
        }
      }
      return true;
    },
    _updateOpacity: function() {
      L.DomUtil.setOpacity(this._container, this.options.opacity);
      return true;
    },
    _initContainer: function() {
      var first, stamp, tilePane;
      tilePane = this._map._panes.tilePane;
      first = tilePane.firstChild;
      if (!this._container || tilePane.empty) {
        this._container = L.DomUtil.create("div", "leaflet-layer");
        stamp = L.Util.stamp(this);
        L.DomUtil.addClass(this._container, "layer-" + stamp);
        if (this._insertAtTheBottom && first) {
          tilePane.insertBefore(this._container, first);
        } else {
          tilePane.appendChild(this._container);
        }
        if (this.options.opacity < 1) {
          this._updateOpacity();
        }
      }
      return true;
    },
    _resetCallback: function(e) {
      this._reset(e.hard);
      return true;
    },
    _reset: function(clearOldContainer) {
      var key, tiles;
      key = void 0;
      tiles = this._tiles;
      for (key in tiles) {
        if (tiles.hasOwnProperty(key)) {
          this.fire("tileunload", {
            tile: tiles[key]
          });
        }
      }
      this._tiles = {};
      if (this.options.reuseTiles) {
        this._unusedTiles = [];
      }
      if (clearOldContainer && this._container) {
        this._container.innerHTML = "";
      }
      this._initContainer();
      return true;
    },
    _update: function(e) {
      var bounds, nwTilePoint, seTilePoint, tileBounds, tileSize, zoom;
      if (this._map._panTransition && this._map._panTransition._inProgress) {
        return;
      }
      bounds = this._map.getPixelBounds();
      zoom = this._map.getZoom();
      tileSize = this.options.tileSize;
      if (zoom > this.options.maxZoom || zoom < this.options.minZoom) {
        return;
      }
      nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x), Math.floor(bounds.min.y / tileSize.y));
      seTilePoint = new L.Point(Math.floor(bounds.max.x / tileSize.x), Math.floor(bounds.max.y / tileSize.y));
      tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
      this._addTilesFromCenterOut(tileBounds);
      if (this.options.unloadInvisibleTiles || this.options.reuseTiles) {
        this._removeOtherTiles(tileBounds);
      }
      return true;
    },
    getCenterTile: function() {
      var bounds, center;
      bounds = this.getTilePointAbsoluteBounds();
      if (bounds) {
        center = bounds.getCenter();
        return center;
      } else {
        return false;
      }
    },
    _addTilesFromCenterOut: function(bounds) {
      var center, fragment, i, j, k, len, queue;
      queue = [];
      center = bounds.getCenter();
      j = void 0;
      i = void 0;
      j = bounds.min.y;
      while (j <= bounds.max.y) {
        i = bounds.min.x;
        while (i <= bounds.max.x) {
          if (!((i + ":" + j) in this._tiles)) {
            queue.push(new L.Point(i, j));
          }
          i++;
        }
        j++;
      }
      queue.sort(function(a, b) {
        return a.distanceTo(center) - b.distanceTo(center);
      });
      fragment = document.createDocumentFragment();
      this._tilesToLoad = queue.length;
      k = void 0;
      len = void 0;
      k = 0;
      len = this._tilesToLoad;
      while (k < len) {
        this._addTile(queue[k], fragment);
        k++;
      }
      this._container.appendChild(fragment);
      return true;
    },
    _removeOtherTiles: function(bounds) {
      var kArr, key, tile, x, y;
      kArr = void 0;
      x = void 0;
      y = void 0;
      key = void 0;
      tile = void 0;
      for (key in this._tiles) {
        if (this._tiles.hasOwnProperty(key)) {
          kArr = key.split(":");
          x = parseInt(kArr[0], 10);
          y = parseInt(kArr[1], 10);
          if (x < bounds.min.x || x > bounds.max.x || y < bounds.min.y || y > bounds.max.y) {
            this._removeTile(key);
          }
        }
      }
      return true;
    },
    _removeTile: function(key) {
      var tile;
      tile = this._tiles[key];
      this.fire("tileunload", {
        tile: tile,
        url: tile.src
      });
      if (tile.parentNode === this._container) {
        this._container.removeChild(tile);
      }
      if (this.options.reuseTiles) {
        this._unusedTiles.push(tile);
      }
      tile.src = L.Util.emptyImageUrl;
      this._removeCellsFromTile(tile);
      delete this._tiles[key];
      return true;
    },
    _addTile: function(tilePoint, container) {
      var key, limit, tile, tilePos, zoom;
      tilePos = this._getTilePos(tilePoint);
      zoom = this._map.getZoom();
      key = tilePoint.x + ":" + tilePoint.y;
      limit = Math.pow(2, this._getOffsetZoom(zoom));
      if (!this.options.continuousWorld) {
        if (!this.options.noWrap) {
          tilePoint.x = ((tilePoint.x % limit) + limit) % limit;
        } else if (tilePoint.x < 0 || tilePoint.x >= limit) {
          this._tilesToLoad--;
          return;
        }
        if (tilePoint.y < 0 || tilePoint.y >= limit) {
          this._tilesToLoad--;
          return;
        }
      }
      tile = this._getTile();
      L.DomUtil.setPosition(tile, tilePos);
      this._tiles[key] = tile;
      if (this.options.scheme === "tms") {
        tilePoint.y = limit - tilePoint.y - 1;
      }
      this._loadTile(tile, tilePoint, zoom);
      container.appendChild(tile);
      return true;
    },
    _getOffsetZoom: function(zoom) {
      var options;
      options = this.options;
      zoom = (options.zoomReverse ? options.maxZoom - zoom : zoom);
      return zoom + options.zoomOffset;
    },
    _getTilePos: function(tilePoint) {
      var origin, tileSize;
      origin = this._map.getPixelOrigin();
      tileSize = this.options.tileSize;
      return tilePoint.multiplyBy(tileSize).subtract(origin);
    },
    getTileUrl: function(tilePoint, zoom) {
      return 'noTileUrlForUsThanks';
    },
    _createTileProto: function() {
      var tileSize;
      this._divProto = L.DomUtil.create('div', 'leaflet-tile');
      tileSize = this.options.tileSize;
      this._divProto.style.width = tileSize.x + 'px';
      this._divProto.style.height = tileSize.y + 'px';
      return true;
    },
    _getTile: function() {
      var tile;
      if (this.options.reuseTiles && this._unusedTiles.length > 0) {
        tile = this._unusedTiles.pop();
        this._resetTile(tile);
        return tile;
      }
      return this._createTile();
    },
    _resetTile: function(tile) {
      return true;
    },
    _createTile: function() {
      var tile;
      dbg('_createTile');
      tile = this._divProto.cloneNode(false);
      tile.onselectstart = tile.onmousemove = L.Util.falseFn;
      return tile;
    },
    _loadTile: function(tile, tilePoint, zoom) {
      var absTilePoint, frag, layer;
      tile._layer = this;
      layer = this;
      tile.onload = this._tileOnLoad;
      tile.onerror = this._tileOnError;
      tile._tilePoint = tilePoint;
      absTilePoint = {
        x: tilePoint.x * Math.pow(2, state.zoomDiff()),
        y: tilePoint.y * Math.pow(2, state.zoomDiff())
      };
      layer.tileDrawn(tile);
      frag = getTileLocally(absTilePoint, tile);
      if (frag) {
        layer.populateTile(tile, tilePoint, zoom, frag);
      } else {
        now.getTile(absTilePoint, state.numRows(), function(tileData, atp) {
          frag = betterBuildTile(tile, tileData, atp);
          return layer.populateTile(tile, tilePoint, zoom, frag);
        });
      }
      return tile;
    },
    drawTile: function(tile, tilePoint, zoom, frag) {
      tile.appendChild(frag);
      return true;
    },
    populateTile: function(tile, tilePoint, zoom, frag) {
      tile.appendChild(frag);
      return true;
    },
    tileDrawn: function(tile) {
      tile.className += ' leaflet-tile-drawn';
      this._tileOnLoad.call(tile);
      return true;
    },
    _tileOnLoad: function(e) {
      var layer;
      layer = this._layer;
      this.className += " leaflet-tile-loaded";
      layer.fire("tileload", {
        tile: this,
        url: this.src
      });
      layer._tilesToLoad--;
      if (!layer._tilesToLoad) {
        layer.fire("load");
      }
      return true;
    },
    _tileOnError: function(e) {
      var layer, newUrl;
      layer = this._layer;
      layer.fire("tileerror", {
        tile: this,
        url: this.src
      });
      newUrl = layer.options.errorTileUrl;
      if (newUrl) {
        this.src = newUrl;
      }
      return true;
    },
    _onTileUnload: function(e) {
      var tile;
      tile = e.tile;
      tile.style.display = 'none';
      return true;
    },
    _removeCellsFromTile: function(tile) {
      var c, _i, _len, _ref, _results;
      if (tile._cells) {
        _ref = tile._cells;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          _results.push(c.kill);
        }
        return _results;
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
      if (this._map) {
        bounds = this._map.getPixelBounds();
        tileSize = this.options.tileSize;
        offset = Math.pow(2, state.zoomDiff());
        nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x) * offset, Math.floor(bounds.min.y / tileSize.y) * offset);
        seTilePoint = new L.Point(Math.ceil(bounds.max.x / tileSize.x) * offset, Math.ceil(bounds.max.y / tileSize.y) * offset);
        tileBounds = new L.Bounds(nwTilePoint, seTilePoint);
        return tileBounds;
      } else {
        return false;
      }
    }
  });

}).call(this);
