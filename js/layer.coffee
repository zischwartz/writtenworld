
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
    # this._docFragment = document.createDocumentFragment()
    # for i in [1..30]
    #   cell=this._docFragment.appendChild(document.createElement("span"))
    #   cell.innerHTML = 'A'
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
    
    # tile.innerHTML = tilePoint + ' '+ zoom

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

 
# L.Cell = L.Class.extend
#   includes: L.Mixin.Events
#   options:
#     clickable: true
#     draggable: false
# 
#   initialize: (tile, row, col, options) ->
#     # console.log 'cell initid', tile.className, row, col
#     # console.log tile
#     L.Util.setOptions(this, options)
#     # console.log this
#     this.tile= tile
#     this.row = row
#     this.col = col
#     this._span = document.createElement('span')
#     this._span.innerHTML = '.'
#     tile.appendChild(this._span)
#     L.DomEvent.addListener(this._span, 'click', this._onMouseClick, this)
#     #may be better to write my own event listener that returns the tile object. just base it on the dom id, and look it up. 
#     # probably more powerful anyway, to do it based on the absolute (zoom independent) cell id for the whole world, maintain my own list/obj of objects
#     true
# 
#   _onMouseClick: (e) ->
#     console.log 'click!', e
#     L.DomEvent.stopPropagation(e)
#     this.fire(e.type)
#     console.log(this)
#     setSelected(this)
