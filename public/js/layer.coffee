betterBuildTile= (tile, tileData, absTilePoint)->
  tile._cells = [] #this would be good to use for removing old cells
  frag = document.createDocumentFragment()
  for r in [0..state.numRows()-1]
    for c in [0..state.numCols()-1]
      cellData=tileData["#{absTilePoint.x+c}x#{absTilePoint.y+r}"]
      if cellData
        dbg 'cell loaded from server'
        dbg 'cellData', cellData.contents
        cell=Cell.getOrCreate r, c, tile, cellData.contents, cellData.props
      else
        cell= Cell.getOrCreate r,c, tile
        dbg 'cell created, but others in tile were from server'
      frag.appendChild(cell.span)
      tile._cells.push(cell)
  return frag

getTileLocally =(absTilePoint, tile) ->
  console.log 'getting locally'
  tile._cells = []
  frag = document.createDocumentFragment()
  cellsNeeded = state.numRows()*state.numCols() #cellsNeeded to have a full tile
  for r in [0..state.numRows()-1]
    for c in [0..state.numCols()-1]
      cell=Cell.get(absTilePoint.x+c, absTilePoint.y+r)
      if cell
        cell=Cell.getOrCreate r, c, tile
        frag.appendChild(cell.span)
        dbg 'FOUND CELL--------', cell
        cellsNeeded--
        tile._cells.push(cell)
  if cellsNeeded <=0
    dbg 'we have the entire tile'
    return frag
  else
    tile._cells= null
    return false

L.TileLayer.Dom = L.TileLayer.extend
  # options: { async: false }
  options:
    unloadInvisibleTiles: true
    # reuseTiles: true
    # updateWhenIdle: true

  initialize: (options) ->
    dbg 'init!'
    L.Util.setOptions(this, options)
    this.on 'tileunload', (e) -> this._onTileUnload(e)
    true

  _createTileProto: ->
    dbg 'creatingTileProto'
    this._divProto = L.DomUtil.create('div', 'leaflet-tile')
    tileSize = this.options.tileSize
    this._divProto.style.width = tileSize.x+'px'
    this._divProto.style.height = tileSize.y+'px'
    true

  _createTile: ->
    tile = this._divProto.cloneNode(false)
    tile.onselectstart = tile.onmousemove = L.Util.falseFn
    return tile

  _loadTile: (tile, tilePoint, zoom) ->
    dbg '_loadTile called'
    tile._layer = this
    tile._tilePoint = tilePoint
    tile._zoom = zoom
    tile.onload = this._tileOnLoad
    tile.onerror= this._tileOnError
    if DEBUG
      d= document.createElement 'div'; d.className= 'debug'; d.innerHTML= tilePoint + ' '+ zoom; tile.appendChild d; $(tile).addClass 'debugTile'
    # console.log 'this._layer:', this
    layer =this
    absTilePoint = {x: tilePoint.x*Math.pow(2, state.zoomDiff()), y:tilePoint.y*Math.pow(2, state.zoomDiff())}
    
    #need something here to check if we already have the data for that tile
    frag=getTileLocally(absTilePoint, tile)
    if frag
      layer.drawTile(tile, tilePoint, zoom, frag)
      layer.tileDrawn(tile)
    else
      now.getTile absTilePoint, state.numRows(), (tileData, atp)->
        # console.log tileData
        frag=betterBuildTile(tile, tileData, atp)
        layer.drawTile(tile, tilePoint, zoom, frag)
        layer.tileDrawn(tile)
    true

  drawTile: (tile, tilePoint, zoom, frag)->
    tile.appendChild(frag) # tile.appendChild(content.cloneNode(true))
    # console.log 'drawtile', tile
    true

  _getTile: ->
    dbg '_getTile called'
    return this._createTile()

  tileDrawn: (tile) ->
    dbg 'tileDrawn called'
    tile.className += ' leaflet-tile-drawn'
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
  
  _onTileUnload: (e) ->
    # console.log e
    if e.tile._zoom == map.getZoom()
      dbg 'unload due to pan, easy'
      for c in e.tile._cells
        c.kill()
      # e.tile = null #maybe dont' need to do this
    else if e.tile._zoom < map.getZoom()
      dbg 'zoom in'
      console.log 'unload due to zoom, less easy'
    else if e.tile._zoom > map.getZoom()
      dbg 'zoom out' # this case requires nothing, every cell will still be there
      #on zoom out, we don't need to do anything
      # for c in e.tile._cells
        # c.kill()
      # e.tile = null #maybe dont' need to do this

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
