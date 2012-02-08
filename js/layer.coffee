
# L.TileLayer.Dom = L.TileLayer.extend({
# L.TileLayer.Dom = L.TileLayer

# class L.TileLayer.Dom extends L.TileLayer

L.TileLayer.Dom = L.TileLayer.extend
  options: { async: false }

  initialize: (options) ->
    dbg 'init!'
    L.Util.setOptions(this, options)
    true

  redraw: ->
    for i in this._tiles
      tile = this._tiles[i]
      this._redrawTile(tile)
      true

  _redrawTile: (tile) ->
    this.drawTile(tile, tile._tilePoint, tile._zoom)
    true

  _createTileProto: ->
    dbg 'creatingTileProto'
    this._divProto = L.DomUtil.create('div', 'leaflet-tile')
    tileSize = this.options.tileSize
    this._divProto.style.width = tileSize.x+'px'
    this._divProto.style.height = tileSize.y+'px'
    this._docFragment = document.createDocumentFragment()
    for i in [1..30]
      cell=this._docFragment.appendChild(document.createElement("span"))
      cell.innerHTML = 'A'
    true

  _createTile: ->
    dbg '_createTile called'
    dbg state.zoomDiff()
    # // var tile = this._divProto.cloneNode(true);
    # //alternatively
    tile = this._divProto.cloneNode(true)
    tile.appendChild(this._docFragment.cloneNode(true))
    tile.onselectstart = tile.onmousemove = L.Util.falseFn
    return tile

  _loadTile: (tile, tilePoint, zoom) ->
    dbg '_loadTile called'
    tile._layer = this
    tile._tilePoint = tilePoint
    tile._zoom = zoom
    this.drawTile(tile, tilePoint, zoom)
    if (!this.options.async)
      this.tileDrawn(tile)
    true

  drawTile: (tile, tilePoint, zoom)->
    dbg 'drawTile called, does nothing'
    true

  _getTile: ->
    dbg '_getTile called'
    # console.log('current zoom in _getTile', map.getZoom());
    if (this.options.reuseTiles && this._unusedTiles.length > 0)
      tile = this._unusedTiles.pop()
      this._resetTile(tile)
      return tile
    return this._createTile()

  tileDrawn: (tile) ->
    dbg 'tileDrawn called'
    this._tileOnLoad.call(tile)

  _tileOnLoad: (e) ->
    dbg '_tileOnLoad called'
    layer = this._layer
    this.className += ' leaflet-tile-loaded'
    layer.fire('tileload', {tile: this, url: this.src})
    layer._tilesToLoad--
    if (!layer._tilesToLoad)
      layer.fire('load')
    true
