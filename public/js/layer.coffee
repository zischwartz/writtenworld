# For testing it with a lighter weight object but still DOM elements
# Cell = {}
# Cell.getOrCreate= (a) ->
#   c = {}
#   c.span = document.createElement('span')
#   return c
# 
# Cell.get = -> null

betterBuildTile= (tile, tileData, absTilePoint)->
  dbg 'betterBuildTile'
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

# this is ridiculous TODO fix
getTileLocally =(absTilePoint, tile) ->
  dbg 'getTileLocally'
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


# L.TileLayer = L.Class.extend(
L.DomTileLayer = L.Class.extend
  includes: L.Mixin.Events
  options:
    minZoom: config.minZoom()
    maxZoom: config.maxZoom() #18
    tileSize:
      x: 256
      y: 256
    subdomains: "abc"
    errorTileUrl: ""
    attribution: ""
    opacity: 1
    scheme: "xyz"
    continuousWorld: false
    noWrap: false
    zoomOffset: 0
    zoomReverse: false
    unloadInvisibleTiles: true #  L.Browser.mobile # these should maybe be True
    # updateWhenIdle: false # L.Browser.mobile
    updateWhenIdle: true # L.Browser.mobile
    reuseTiles: false

  initialize: (options, urlParams) -> #removed url param
    if typeof @options.tileSize is "number"
      @options.tileSize =
        x: @options.tileSize
        y: @options.tileSize
    L.Util.setOptions this, options
    
    # I dislike this, but removeOtherTiles isn't hitting the ones I need to remove. or unload? I think I don't understand the difference 
    this.on 'tileunload', (e) -> this._onTileUnload(e)

    # @_url = url
    subdomains = @options.subdomains
    @options.subdomains = subdomains.split("")  if typeof subdomains is "string"
    true

  onAdd: (map, insertAtTheBottom) ->
    @_map = map
    @_insertAtTheBottom = insertAtTheBottom
    @_initContainer()
    @_createTileProto()
    map.on "viewreset", @_resetCallback, this
    map.on "moveend", @_update, this
    unless @options.updateWhenIdle
      @_limitedUpdate = L.Util.limitExecByInterval(@_update, 150, this)
      map.on "move", @_limitedUpdate, this
    @_reset()
    @_update()
    return

  onRemove: (map) ->
    # XXX
    # console.log 'tilePane'
    # console.log map._panes.tilePane
    # console.log '@_container'
    # console.log @_container

    # $(@_container).remove()
    # console.log 'onRemove called'
    map._panes.tilePane.removeChild @_container
    map.off "viewreset", @_resetCallback, this
    map.off "moveend", @_update, this
    map.off "move", @_limitedUpdate, this  unless @options.updateWhenIdle
    @_container = null
    @_map = null
    true

  getAttribution: ->
    @options.attribution

  setOpacity: (opacity) ->
    @options.opacity = opacity
    @_updateOpacity()  if @_map
    i = undefined
    tiles = @_tiles
    if L.Browser.webkit
      for i of tiles
        tiles[i].style.webkitTransform += " translate(0,0)"  if tiles.hasOwnProperty(i)
    true

  _updateOpacity: ->
    L.DomUtil.setOpacity @_container, @options.opacity
    true

  _initContainer: ->
    tilePane = @_map._panes.tilePane
    first = tilePane.firstChild
    # console.log tilePane
    # console.log @_container
    if not @_container or tilePane.empty
      @_container = L.DomUtil.create("div", "leaflet-layer")
      if @_insertAtTheBottom and first
        # console.log 'inserted at bottom'
        tilePane.insertBefore @_container, first
      else
        # console.log 'appended child'
        tilePane.appendChild @_container
      @_updateOpacity()  if @options.opacity < 1
    true

  _resetCallback: (e) ->
    @_reset e.hard
    true

  _reset: (clearOldContainer) ->
    dbg '_reset called'
    key = undefined
    tiles = @_tiles
    for key of tiles
      if tiles.hasOwnProperty(key)
        @fire "tileunload",
          tile: tiles[key]
    @_tiles = {}
    @_unusedTiles = []  if @options.reuseTiles
    @_container.innerHTML = ""  if clearOldContainer and @_container
    @_initContainer()
    true

  _update: (e) ->
    dbg '_update'
    return  if @_map._panTransition and @_map._panTransition._inProgress
    bounds = @_map.getPixelBounds()
    zoom = @_map.getZoom()
    tileSize = @options.tileSize
    return  if zoom > @options.maxZoom or zoom < @options.minZoom
    nwTilePoint = new L.Point(Math.floor(bounds.min.x / tileSize.x), Math.floor(bounds.min.y / tileSize.y))
    seTilePoint = new L.Point(Math.floor(bounds.max.x / tileSize.x), Math.floor(bounds.max.y / tileSize.y))
    tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
    @_addTilesFromCenterOut tileBounds
    @_removeOtherTiles tileBounds  if @options.unloadInvisibleTiles or @options.reuseTiles
    true

  getCenterTile: () ->
    bounds= @getTilePointAbsoluteBounds()
    if bounds #this is always used inside a poll, as it's hard to see if our tiles really have loaded
      center = bounds.getCenter()
      return center
    else
      return false

  _addTilesFromCenterOut: (bounds) ->
    queue = []
    center = bounds.getCenter()
    j = undefined
    i = undefined
    j = bounds.min.y
    while j <= bounds.max.y
      i = bounds.min.x
      while i <= bounds.max.x
        queue.push new L.Point(i, j)  unless (i + ":" + j) of @_tiles
        i++
      j++
    queue.sort (a, b) ->
      a.distanceTo(center) - b.distanceTo(center)

    fragment = document.createDocumentFragment()
    @_tilesToLoad = queue.length
    k = undefined
    len = undefined
    k = 0
    len = @_tilesToLoad

    while k < len
      @_addTile queue[k], fragment
      k++
    @_container.appendChild fragment
    true

  _removeOtherTiles: (bounds) ->
    # console.log '_removeOtherTiles called'
    kArr = undefined
    x = undefined
    y = undefined
    key = undefined
    tile = undefined
    for key of @_tiles
      if @_tiles.hasOwnProperty(key)
        kArr = key.split(":")
        x = parseInt(kArr[0], 10)
        y = parseInt(kArr[1], 10)
        # doesn't apply on zooms? only pan? 
        if x < bounds.min.x or x > bounds.max.x or y < bounds.min.y or y > bounds.max.y
          dbg 'outa bounds, REMOVE THAT SHIT'
          @_removeTile key
    true

  _removeTile: (key) ->
    # console.log 'remove tile called yo!'
    tile = @_tiles[key]
    @fire "tileunload",
      tile: tile
      url: tile.src

    @_container.removeChild tile  if tile.parentNode is @_container
    @_unusedTiles.push tile  if @options.reuseTiles
    tile.src = L.Util.emptyImageUrl

    @_removeCellsFromTile(tile)

    delete @_tiles[key]
    true

  _addTile: (tilePoint, container) ->
    tilePos = @_getTilePos(tilePoint)
    zoom = @_map.getZoom()
    key = tilePoint.x + ":" + tilePoint.y
    limit = Math.pow(2, @_getOffsetZoom(zoom))
    unless @options.continuousWorld
      unless @options.noWrap
        tilePoint.x = ((tilePoint.x % limit) + limit) % limit
      else if tilePoint.x < 0 or tilePoint.x >= limit
        @_tilesToLoad--
        return
      if tilePoint.y < 0 or tilePoint.y >= limit
        @_tilesToLoad--
        return
    tile = @_getTile()
    L.DomUtil.setPosition tile, tilePos
    @_tiles[key] = tile
    tilePoint.y = limit - tilePoint.y - 1  if @options.scheme is "tms"
    @_loadTile tile, tilePoint, zoom
    container.appendChild tile
    # console.log '_addTile called'
    true

  _getOffsetZoom: (zoom) ->
    options = @options
    zoom = (if options.zoomReverse then options.maxZoom - zoom else zoom)
    zoom + options.zoomOffset

  _getTilePos: (tilePoint) ->
    origin = @_map.getPixelOrigin()
    tileSize = @options.tileSize
    tilePoint.multiplyBy(tileSize).subtract origin

  getTileUrl: (tilePoint, zoom) ->
    return 'noTileUrlForUsThanks'

  _createTileProto: ->
    dbg 'creatingTileProto'
    @_divProto = L.DomUtil.create('div', 'leaflet-tile')
    tileSize = this.options.tileSize
    @_divProto.style.width = tileSize.x+'px'
    @_divProto.style.height = tileSize.y+'px'
    true

  _getTile: ->
    if @options.reuseTiles and @_unusedTiles.length > 0
      tile = @_unusedTiles.pop()
      @_resetTile tile
      return tile
    @_createTile()

  _resetTile: (tile) ->
    # console.log '_resetTile called, and the function does nothing'
    true

  _createTile: ->
    dbg '_createTile'
    tile = @_divProto.cloneNode(false)
    tile.onselectstart = tile.onmousemove = L.Util.falseFn
    tile

  _loadTile: (tile, tilePoint, zoom) ->
    tile._layer = this
    layer = this
    tile.onload = @_tileOnLoad
    tile.onerror = @_tileOnError
    # tile.src = @getTileUrl(tilePoint, zoom)
    tile._tilePoint = tilePoint
    absTilePoint = {x: tilePoint.x*Math.pow(2, state.zoomDiff()), y:tilePoint.y*Math.pow(2, state.zoomDiff())}
    # dbg 'loadTile called for abstp: ', absTilePoint.x, absTilePoint.y
    layer.tileDrawn(tile)
 
    # if state.zoomDiff() > 4 # only doTimeout if its zoomed out far enough
    #   dbg 'popualteDelay timer active'
    #   $(tile).doTimeout 'populateDelay', 500, ->
    #     frag=getTileLocally(absTilePoint, tile)
    #     if frag
    #       layer.populateTile(tile, tilePoint, zoom, frag)
    #     else
    #       now.getTile absTilePoint, state.numRows(), (tileData, atp)->
    #         frag=betterBuildTile(tile, tileData, atp)
    #         layer.populateTile(tile, tilePoint, zoom, frag)
    #     return false #so it doesn't poll
    # else

    # check index of tiles otherwise TODO
    frag=getTileLocally(absTilePoint, tile)
    if frag
      layer.populateTile(tile, tilePoint, zoom, frag)
    else
      now.getTile absTilePoint, state.numRows(), (tileData, atp)->
        frag=betterBuildTile(tile, tileData, atp)
        layer.populateTile(tile, tilePoint, zoom, frag)
    tile

  drawTile: (tile, tilePoint, zoom, frag)->
    tile.appendChild(frag) # tile.appendChild(content.cloneNode(true))
    # tile.innerHTML= 'hi'
    # dbg 'drawtile for: ', tilePoint.x, tilePoint.y
    dbg 'drawTile'
    true
   
  populateTile: (tile, tilePoint, zoom, frag) ->
    dbg 'populate tile called'
    tile.appendChild(frag)
    true

  tileDrawn: (tile) ->
    dbg  'tileDrawn called'
    tile.className += ' leaflet-tile-drawn'
    # $.doTimeout 200, ->
    #   dbg 'tiledrawntimer'
    #   tile.className += ' leaflet-tile-drawn'
    #   return false
    dbg 'tileDrawn'
    @_tileOnLoad.call(tile)
    true

  _tileOnLoad: (e) ->
    # dbg '_tileOnLoad called'
    layer = @_layer
    @className += " leaflet-tile-loaded"
    # $.doTimeout 500, =>
    #   console.log 'tiledrawntimer'
    #   @className += ' leaflet-tile-loaded'
    #   return false
    layer.fire "tileload",
      tile: this
      url: @src

    layer._tilesToLoad--
    layer.fire "load"  unless layer._tilesToLoad
    dbg '_tileOnLoad'
    true

  _tileOnError: (e) ->
    dbg '_tileOnError'
    layer = @_layer
    layer.fire "tileerror",
      tile: this
      url: @src

    newUrl = layer.options.errorTileUrl
    @src = newUrl  if newUrl
    true

  _onTileUnload: (e) ->
    dbg e
    dbg '_onTileUnload !'
    # $(e.tile).doTimeout 'populateDelay' #cancels the timer
    # console.log 'tile to unload:'
    # console.log e.tile
    tile = e.tile
    #the fix!
    tile.style.display = 'none'
    #what was I doing below? tile doesn't have a ._zoom prop. I could give it one...
    # better to hook in to the _remove func
 
#     if e.tile._zoom == map.getZoom()
#       dbg 'unload due to pan, easy'
#       # for c in e.tile._cells
#       #   c.kill()
#       # e.tile = null #maybe dont' need to do this
#     else if e.tile._zoom < map.getZoom()
#       dbg 'unload due to zoom in, less easy'
#     else if e.tile._zoom > map.getZoom()
#       dbg 'zoom out' # this case requires nothing, every cell will still be there
    true

  _removeCellsFromTile: (tile) ->
    if tile._cells
      for c in tile._cells
        c.kill

  getTilePointBounds: ->
    bounds = this._map.getPixelBounds()
    tileSize= this.options.tileSize
    nwTilePoint = new L.Point( Math.floor(bounds.min.x / tileSize.x), Math.floor(bounds.min.y / tileSize.y))
    seTilePoint = new L.Point( Math.floor(bounds.max.x / tileSize.x), Math.floor(bounds.max.y / tileSize.y))
    tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
    tileBounds

  # getTilePointAbsoluteBoundsTrue: -> #this version doesn't have the additional buffertile, for use with getCenterTile
  #   bounds = this._map.getPixelBounds()
  #   tileSize= this.options.tileSize
  #   offset = Math.pow 2, state.zoomDiff()
  #   nwTilePoint = new L.Point( Math.floor(bounds.min.x / tileSize.x)*offset, Math.floor(bounds.min.y / tileSize.y)*offset)
  #   seTilePoint = new L.Point( Math.floor(bounds.max.x / tileSize.x)*offset, Math.floor(bounds.max.y / tileSize.y)*offset)
  #   tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
  #   tileBounds

  getTilePointAbsoluteBounds: ->
    if this._map
      bounds = this._map.getPixelBounds()
      tileSize= this.options.tileSize
      offset = Math.pow 2, state.zoomDiff()
      nwTilePoint = new L.Point( Math.floor(bounds.min.x / tileSize.x)*offset, Math.floor(bounds.min.y / tileSize.y)*offset)
      seTilePoint = new L.Point( Math.ceil(bounds.max.x / tileSize.x)*offset, Math.ceil(bounds.max.y / tileSize.y)*offset)
      tileBounds = new L.Bounds(nwTilePoint, seTilePoint)
    # console.log tileBounds
      return tileBounds
    else
      return false
