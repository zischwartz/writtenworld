
window.buildTile = (tile)  ->
  tile._cells = {}
  frag = document.createDocumentFragment()
  for r in [0..state.numRows()-1] # -1 because using 0 index
    for c in [0..state.numCols()-1]
      cell = new Cell r, c, tile
      frag.appendChild(cell.span)
  return frag


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
    true

  _createTile: ->
    dbg '_createTile called'
    tile = this._divProto.cloneNode(false)
    # console.log tile
    tile.onselectstart = tile.onmousemove = L.Util.falseFn
    return tile

  _loadTile: (tile, tilePoint, zoom) ->
    dbg '_loadTile called'
    tile._layer = this
    tile._tilePoint = tilePoint
    tile._zoom = zoom
    
    if DEBUG
      d= document.createElement 'div'
      d.className= 'debug'
      d.innerHTML= tilePoint + ' '+ zoom
      tile.appendChild d
      $(tile).addClass 'debugTile'
    this.drawTile(tile, tilePoint, zoom)
    if (!this.options.async)
      this.tileDrawn(tile)
    true

  drawTile: (tile, tilePoint, zoom)->
    content = buildTile(tile)
    tile.appendChild(content) # tile.appendChild(content.cloneNode(true))
    console.log 'drawtile'
    true

  _getTile: ->
    dbg '_getTile called'
    # console.log('current zoom in _getTile', map.getZoom())
    if (this.options.reuseTiles && this._unusedTiles.length > 0)
      tile = this._unusedTiles.pop()
      this._resetTile(tile)
      return tile
    return this._createTile()

  tileDrawn: (tile) ->
    dbg 'tileDrawn called'
    # tile.className += ' leaflet-tile-drawn'
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

  getTilePointBounds: ->
    bounds = this._map.getPixelBounds()
    tileSize= this.options.tileSize
    nwTilePoint = new L.Point( Math.floor(bounds.min.x / tileSize.x), Math.floor(bounds.min.y / tileSize.y))
    seTilePoint = new L.Point( Math.floor(bounds.max.x / tileSize.x), Math.floor(bounds.max.y / tileSize.y))
    tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
    tileBounds

  getTilePointAbsoluteBounds: ->
    bounds = this._map.getPixelBounds()
    tileSize= this.options.tileSize
    offset = Math.pow 2, state.zoomDiff()
    nwTilePoint = new L.Point( Math.floor(bounds.min.x / tileSize.x)*offset, Math.floor(bounds.min.y / tileSize.y)*offset)
    seTilePoint = new L.Point( Math.floor(bounds.max.x / tileSize.x)*offset, Math.floor(bounds.max.y / tileSize.y)*offset)
    tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
    tileBounds
