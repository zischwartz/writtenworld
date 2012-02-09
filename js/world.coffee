window.DEBUG = false
# window.DEBUG = true

window.Configuration = class Configuration
  constructor: (spec = {}) ->
    # @tileSize = -> spec.tileSize ? {x: 128, y: 256}
    @tileSize = -> spec.tileSize ? {x: 192, y: 256}
    # @tileSize = -> spec.tileSize ? {x: 256, y: 256}
    @maxZoom = -> spec.maxZoom ? 18
    @defaultChar = -> spec.defaultChar ? " "

window.config = new Configuration

window.state =
  selectedCellKey: null
  selectedCellEl: null
  # selectedEl: null
  # selectedTileKey: null
  # selectedCellKey: null
  # lastClick: null
  # lastChar: null
  # canRead: true
  # canWrite: true
  # geoInitialPos: null
  # geoCurrentPos: null
  # geoAccuracy: null
  writeDirection: 'right'
  zoomDiff: ->
    config.maxZoom()-map.getZoom()#+1 #+1 here is that the true maxzoom is one greater than you can acutally zoom (and should be one cell per tile)
  numRows: ->
    numRows = Math.pow(2, state.zoomDiff())# *2
  numCols: ->
    numCols = Math.pow(2, state.zoomDiff())# *2 # 3:2 RATIO OF ROWS TO COLUMNS. Should probably put this in config!

#should set these up here beyond null, so it's clear what they represent

setTileStyle = ->
 width = config.tileSize().x/state.numCols()
 height = config.tileSize().y/state.numRows()
 fontSize = height#width*1.5 #why not
 rules = []
 rules.push(".leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 # console.log rules
 $("#dynamicStyles").text rules.join("\n")

# takes the object, not the dom element
window.setSelected = (cell) ->
  dbg 'selecting', cell
  if state.selectedEl
    $(state.selectedEl).removeClass('selected')
  state.selectedEl=cell.span
  $(cell.span).addClass('selected')
  state.selectedCell =cell
  true


moveCursor = (direction, from = state.selectedCell) ->
  dbg 'move cursor'
  target = {}
  
  [target.x, target.y] = from.key.slice(1).split('x') #splice to get rid of first char (only there to follow w3 spec for dom ids)
  target.x = parseInt target.x, 10
  target.y = parseInt target.y, 10
  
  switch direction
    when 'up'
      target.y =  target.y-1
    when 'down'
      target.y =  target.y+1
    when 'left'
      target.x =  target.x-1
    when 'right'
      target.x =  target.x+1
  
  key = "c#{target.x}x#{target.y}"
  targetCell=Cell.all()[key]
  setSelected(targetCell)
  true
#
#INITIALIZER 
initializeInterface = ->
  $("#map").click (e) ->
    if $(e.target).hasClass 'cell'
      cell=Cell.all()[e.target.id]
      setSelected(cell)
    else
      return false

  inputEl = $ "#input"
  inputEl.focus()

  inputEl.keypress (e) ->
    c = String.fromCharCode e.which
    dbg  c,  'PRESSED!!!!'
    state.selectedCell.write( c)
    moveCursor(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")
      

  inputEl.keydown (e) ->
    isNearEdge = false
    selectedPP= $(state.selectedEl).offset()
    panOnDist = 200
    panByDist = 50
    switch e.which
      when 9 #tab
        e.preventDefault()
        return false
      when 38
        moveCursor('up')
        if selectedPP.top < panOnDist
          pan(0, 0-panByDist)
      when 40
        moveCursor('down')
        if selectedPP.top > document.height-panOnDist*1.5 #need to include size of a cell in state
          pan(0,panByDist)
      when 39
        moveCursor('right')
        if selectedPP.left > document.width-panOnDist
          pan(panByDist, 0)
      when 37
        moveCursor('left')
        if selectedPP.left < panOnDist
          pan(0-panByDist, 0)


    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
    #   console.log("input was a letter, number, hyphen, underscore or space")


jQuery ->
  tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png'
  tileServeLayer = new L.TileLayer(tileServeUrl, {maxZoom: config.maxZoom()})
  window.map = new L.Map('map', {center: new L.LatLng(51.505, -0.09), zoom: 16, scrollWheelZoom: false}).addLayer(tileServeLayer)
  # initializeGeo()
  window.domTiles = new L.TileLayer.Dom {tileSize: config.tileSize()}
  
  testMarker = new L.Marker map.getCenter()
  map.addLayer(testMarker)
  testMarker.on 'click', (e) -> console.log e

  map.addLayer(domTiles)
  setTileStyle() #set initial
  map.on 'zoomend', ->
    setTileStyle()
  initializeInterface()
  true
# END DOC READY


window.Cell = class Cell
  all = {}
  @all: -> all
  
  generateKey: =>
    x = @tile._tilePoint.x * Math.pow(2, state.zoomDiff())
    y = @tile._tilePoint.y * Math.pow(2, state.zoomDiff())
    x+= @col
    y+= @row
    return "c#{x}x#{y}"

  constructor: (@row, @col, @tile, @contents = config.defaultChar(), @properties=null, @events=null) ->
    @history = {}
    @timestamp = null #just use servertime
    @key = this.generateKey()
    all[@key]=this
    @span = document.createElement('span')
    @span.innerHTML= config.defaultChar()
    @span.id= @key
    @span.className= 'cell'

  write: (c) ->
    @contents= c
    @span.innerHTML = c

#Having to create a point is dumb
pan = (x, y)->
  p= new L.Point( x, y )
  map.panBy(p)
  map

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
