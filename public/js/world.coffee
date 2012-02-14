window.DEBUG = false
# window.DEBUG = true

window.Configuration = class Configuration
  constructor: (spec = {}) ->
    # @tileSize = -> spec.tileSize ? {x: 128, y: 256} #the best powers of 2
    # @tileSize = -> spec.tileSize ? {x: 128, y: 196}
    # @tileSize = -> spec.tileSize ? {x: 128, y: 160} #this one is good, but 160 isn't a power of 2
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    # @tileSize = -> spec.tileSize ? {x: 256, y: 256}
    # @tileSize = -> spec.tileSize ? {x: 192, y: 224}
    @maxZoom = -> spec.maxZoom ? 20 # was 18, current image tiles are only 18
    @defaultChar = -> spec.defaultChar ? " "

#ratio of row/cols in WW was .77.. (14/18)

window.config = new Configuration

window.state =
  selectedCell: null
  lastClickCell: null
  # canRead: true
  # canWrite: true
  # geoInitialPos: null
  # geoCurrentPos: null
  # geoAccuracy: null
  writeDirection: 'right'
  zoomDiff: ->
    config.maxZoom()-map.getZoom()
  numRows: ->
    numRows = Math.pow(2, state.zoomDiff())
  numCols: ->
    numCols = Math.pow(2, state.zoomDiff()) #old method for setting ratio was to multiply this, but now we just change the tilesize
  cellWidth: ->
    config.tileSize().x/state.numCols()
  cellHeight: ->
    config.tileSize().y/state.numRows()
#should set these up here beyond null, so it's clear what they represent

setTileStyle = ->
 width = state.cellWidth()
 height = state.cellHeight()
 fontSize = height*0.9 #width*1.5 #why not
 rules = []
 rules.push("div.leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
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
  now.setSelectedCell cellKeyToXY cell.key
  true


moveCursor = (direction, from = state.selectedCell) ->
  dbg 'move cursor'
  target = cellKeyToXY(from.key)
  
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

#INITIALIZER 
initializeInterface = ->
  dbg 'initializing interface'
  $("#map").click (e) ->
    dbg e
    if $(e.target).hasClass 'cell'
      cell=Cell.all()[e.target.id]
      state.lastClickCell = cell
      setSelected(cell)
      inputEl.focus()
    else
      inputEl.focus()
      return false

  window.inputEl = $ "#input"
  inputEl.focus()
  map.on 'zoomend', ->
    inputEl.focus()

  inputEl.keypress (e) ->
    if e.which ==13
      moveCursor 'down', state.lastClickCell
      panIfAppropriate('down')
      state.lastClickCell = state.selectedCell
    else
      c = String.fromCharCode e.which
      dbg  c,  'PRESSED!!!!'
      state.selectedCell.write( c)

      cellPoint = cellKeyToXY state.selectedCell.key
      now.writeCell(cellPoint, c)

      moveCursor(state.writeDirection)
      panIfAppropriate(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")

  inputEl.keydown (e) ->
    # console.log e, e.which,' keydownd'
    switch e.which
      when 9 #tab
        e.preventDefault()
        return false
      when 38
        moveCursor('up')
        panIfAppropriate('up')
      when 40
        moveCursor('down')
        panIfAppropriate('down')
      when 39
        moveCursor('right')
        panIfAppropriate('right')
      when 37
        moveCursor('left')
        panIfAppropriate('left')
      when 8
        moveCursor('left')
        panIfAppropriate('left')
        state.selectedCell.write(' ')


#end interface initi

panIfAppropriate = (direction)->
  selectedPP= $(state.selectedEl).offset()
  panOnDist = 200
  panByDist = state.cellHeight()
  if direction == 'up'
    if selectedPP.top < panOnDist
      pan(0, 0-panByDist)
  if direction == 'down'
    if selectedPP.top > document.height-panOnDist*1.5 #need to include size of a cell in state
      pan(0,panByDist)
  if direction == 'right'
      if selectedPP.left > document.width-panOnDist
        pan(panByDist, 0)
  if direction == 'left'
      if selectedPP.left < panOnDist
        pan(0-panByDist, 0)


jQuery ->
  # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png'
  tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/999/256/{z}/{x}/{y}.png'
  tileServeLayer = new L.TileLayer(tileServeUrl, {maxZoom: config.maxZoom()})
  centerPoint= new L.LatLng(40.714269, -74.005972)
  window.map = new L.Map('map', {center: centerPoint, zoom: 17, scrollWheelZoom: false})#.addLayer(tileServeLayer)
  # initializeGeo()
  window.domTiles = new L.TileLayer.Dom {tileSize: config.tileSize()}
 
  # map.locateAndSetView(17)
  # map.on 'locationfound', (e)->
  #   radius = e.accuracy / 2
  #   circle = new L.Circle(e.latlng, radius)
  #   map.addLayer(circle)
  #   return true

  now.ready ->
    map.addLayer(domTiles)
    setTileStyle() #set initial
    map.on 'zoomend', ->
      setTileStyle()
    initializeInterface()

    now.setBounds domTiles.getTilePointAbsoluteBounds()

    now.drawCursors = (users) ->
      $('.otherSelected').removeClass('otherSelected') #this is a dumb way 
      # console.log users, 'users'
      for id, user of users
        if user.selected.x
          otherSelected = Cell.get(user.selected.x, user.selected.y)
          $(otherSelected.span).addClass('otherSelected')
    
    now.drawEdits = (edits) ->
      # console.log edits
      for id, edit of  edits
        c=Cell.get(edit.cellPoint.x, edit.cellPoint.y)
        c.write(edit.content)

    map.on 'moveend', ->
      now.setBounds domTiles.getTilePointAbsoluteBounds()
    map.on 'zoomend', ->
      now.setBounds domTiles.getTilePointAbsoluteBounds()

  true
# END DOC READY




window.Cell = class Cell
  all = {}
  @all: -> all
  @get: (x,y) ->
    return all["c#{x}x#{y}"]

  @count:->
    i=0
    for c of all
      i++
    return  i

  generateKey: =>
    @x = @tile._tilePoint.x * Math.pow(2, state.zoomDiff())+@col
    @y = @tile._tilePoint.y * Math.pow(2, state.zoomDiff())+@row
    return "c#{@x}x#{@y}"

  constructor: (@row, @col, @tile, @contents = config.defaultChar(), @properties=null, @events=null) ->
    @history = {}
    @timestamp = null #just use servertime
    @key = this.generateKey()
    all[@key]=this
    @span = document.createElement('span')
    @span.innerHTML= @contents
    @span.id= @key
    @span.className= 'cell'

  write: (c) ->
    @contents= c
    @span.innerHTML = c

  kill: ->
    dbg 'killing a cell'#, @key
    @span= null
    delete all[@key]


  @getOrCreate:(row, col, tile, contents=null) ->
    x=tile._tilePoint.x * Math.pow(2, state.zoomDiff())+col
    y=tile._tilePoint.y * Math.pow(2, state.zoomDiff())+row
    cell=Cell.get(x,y)
    if cell
      return cell
    else
      cell = new Cell row, col, tile, contents
      return cell

    
#Having to create a point is dumb
pan = (x, y)->
  p= new L.Point( x, y )
  map.panBy(p)
  map

cellKeyToXY = (key) ->
  target= {}
  [target.x, target.y] = key.slice(1).split('x') #splice to get rid of first char (only there to follow w3 spec for dom ids)
  target.x = parseInt target.x, 10
  target.y = parseInt target.y, 10
  return target

window.cellXYToKey= (target) ->
  return "c#{target.x}x#{target.y}"

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
