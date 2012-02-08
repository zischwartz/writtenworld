window.DEBUG = true

window.Configuration = class Configuration
  constructor: (spec = {}) ->
    @tileSize = -> spec.tileSize ? {x: 128, y: 256}
    @maxZoom = -> spec.maxZoom ? 18
    @defaultChar = -> spec.defaultChar ? "."

window.config = new Configuration

window.state =
  selectedEl: null
  selectedTileKey: null
  selectedCellKey: null
  # lastClick: null
  # lastChar: null
  # canRead: true
  # canWrite: true
  geoInitialPos: null
  geoCurrentPos: null
  geoAccuracy: null
  writeDirection: 'right'
  zoomDiff: ->
    config.maxZoom()-map.getZoom()+1 #log here is that the true maxzoom is one greater than you can acutally zoom (and should be one cell per tile)
  numRows: ->
    numRows = Math.pow(2, state.zoomDiff())# *2
  numCols: ->
    numCols = Math.pow(2, state.zoomDiff())# *2 # 3:2 RATIO OF ROWS TO COLUMNS. Should probably put this in config!

#should set these up here beyond null, so it's clear what they represent

setSelected = (el) ->
  if state.selectedEl
    state.selectedEl.className.baseVal = ''
  state.selectedEl=el
  el.className.baseVal= 'selected'
  state.selectedTileKey = el.tileKey
  state.selectedCellKey = el.cellKey
  true


moveCursor = (direction, from = state.selected) ->
  # if not from then from= state.selected
  console.log 'from',from
  console.log direction
  # console.log 'Tile.getcellcoords',Tile.getCellCoords(from)
  # coords= Tile.getCellCoords(from)
  target = {}
  [target.col, target.row] = state.selectedCellKey.split('/')
  [zoom, target.lat, target.lng] = state.selectedTileKey.split('/')
  
  switch direction
    when 'up'
      target.row =  target.row-1
    when 'down'
      target.row =  target.row+1
    when 'left'
      target.col =  target.col-1
    when 'right'
      target.col =  target.col+1
  
  if target.row < 0
    target.lng= target.lng-1
    target.row = state.numRows()-1

  if target.row >= state.numRows()
    target.lng= target.lng+1
    target.row = 0

  if target.col < 0
    target.lat= target.lat-1
    target.col = state.numCols()-1

  if target.col >= state.numCols()
    target.lat= target.lat+1
    target.col = 0
  
  # el
  setSelected(el)
  # setSelected HERE

  true
#
#INITIALIZER 
initializeInterface = ->

  # $("#map").click (e) ->
  #   console.log e
  #   setSelected(e.target)
  #   true

  inputEl = $ "#input"
  inputEl.focus()

  inputEl.keypress (e) ->
    c = String.fromCharCode e.which
    console.log c,  'PRESSED!!!!'
    state.lastChar= c
    state.selectedTile.write(state.selectedRC, c)
    moveCursor(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")
      

  inputEl.keydown (e) ->
    isNearEdge = false
    selectedPP= $(state.selectedEl).offset()
    panOnDist = 150

    switch e.which
      when 9 #tab
        e.preventDefault()
        return false
      when 38
        moveCursor('up')
        if selectedPP.top < panOnDist
          map.panBy(0,-30)
      when 40
        moveCursor('down')
        if selectedPP.top > document.height-panOnDist
          map.panBy(0,30)
      when 39
        moveCursor('right')
        if selectedPP.left > document.width-panOnDist
          map.panBy(30, 0)
      when 37
        moveCursor('left')
        if selectedPP.left < panOnDist
          map.panBy(-30, 0)

    # console.log e
    # c = String.fromCharCode e.which
    # console.log 'button down: ' , c

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
    #   console.log("input was a letter, number, hyphen, underscore or space")


jQuery ->
  tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png'
  tileServeLayer = new L.TileLayer(tileServeUrl, {maxZoom: config.maxZoom()})
  window.map = new L.Map('map', {center: new L.LatLng(51.505, -0.09), zoom: 16}).addLayer(tileServeLayer)
  # initializeGeo()
  window.domTiles = new L.TileLayer.Dom {tileSize: config.tileSize()}
  
  map.addLayer(domTiles)

  initializeInterface()
  true
# END DOC READY

buildTile = ->
      for r in [0..state.numRows()]
        for c in [0..state.numCols()]
           cell.setAttribute("y", cellHeight*r)
           cell.setAttribute("x", cellWidth*c)
           cell.setAttribute("font-size", cellWidth)
           cell.textContent= config.defaultChar()
           cell.tileKey = tile.key
           cell.cellKey = c + '/' + r
    true

#CLASSES
#
#
# 
# window.Tile = class Tile
#   all = []
# 
#   constructor: (@tile, @contents=null) ->
#     @cells = {}
#     for r in [0..config.numRows()]
#       for c in [0..config.numCols()]
#         cell =  new Cell(row=r, col=c, tile=this, contents ='.')
#         # do server before doing details, that code should be identical/involve now
#         name = r + '-' + c
#         @cells[name] = cell
#    
#     all.push(this)
#   
#   kill: =>
#     all.remove this
#     $(@node).remove()
#     @node = null
    # delete this
  
  # cells: => @cells

  # getCell: (row, col) =>
  #   # console.log('@node', @node)
  #   rows = @node.childNodes[0].childNodes[0]#.childNodes[0]
  #   rows.childNodes[row].childNodes[col]
# 
#   write: (rowcol, t) =>
#     state.selected.innerHTML= t
#     true
# 
#   @all: -> all
# 
# window.Cell = class Cell
#   constructor: (@row, @col, @tile, @contents = null, @properties=null, @events=null) ->
#     @history = {}
#     @timestamp = null #just use servertime
#     console.log 'making cell' 
# 
 

# UTILITY FUNCTIONS
filter = (list, func) -> x for x in list when func(x)

Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

getNodeIndex = (node) -> $(node).parent().children().index(node)

window.dbg = (message, more...)->
  if DEBUG
    console.log message
    return true
  if DEBUG and more
    console.log message, more
    return true
  return true
