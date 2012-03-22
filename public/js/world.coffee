# window.DEBUG = false
window.DEBUG = true
window.USEMAP = false
# window.USEMAP = true

window.Configuration = class Configuration
  constructor: (spec = {}) ->
    # @tileSize = -> spec.tileSize ? {x: 128, y: 256} #the best powers of 2
    # @tileSize = -> spec.tileSize ? {x: 128, y: 196}
    # @tileSize = -> spec.tileSize ? {x: 128, y: 160} #this one is good, but 160 isn't a power of 2
    @tileSize = -> spec.tileSize ? {x: 192, y: 256} #been using THIS one
    # @tileSize = -> spec.tileSize ? {x: 256, y: 256}
    # @tileSize = -> spec.tileSize ? {x: 192, y: 224} #liking this one
    @maxZoom = -> spec.maxZoom ? 20 # was 18, current image tiles are only 18
    @defaultChar = -> spec.defaultChar ? " "

#ratio of row/cols in WW was .77.. (14/18)

window.config = new Configuration

window.state =
  selectedCell: null
  lastClickCell: null
  color: null
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
 
  if cell.props
    if cell.props.color == 'c3'
     console.log 'c33333'
     cell.cloneSpan(1)
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
  if not targetCell
    return false
     # throw 'cell does not exist'
  setSelected(targetCell)
  true

centerCursor = ->
  target = window.domTiles.getCenterTile()
  key = "c#{target.x}x#{target.y}"
  targetCell=Cell.all()[key]
  if not targetCell
    return false
     # throw 'cell does not exist'
  setSelected(targetCell)
  true

#INTERFACE INITIALIZER 
initializeInterface = ->
  dbg 'initializing interface'
  $("#map").click (e) ->
    # console.log e.target
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
    dbg  e.which, 'pressed'
    if e.which in [0, 13, 32, 9, 38, 40, 39, 8]
      console.log 'SPECIAL KEY, screw this keypress'
      return false
    else
      c = String.fromCharCode e.which
      console.log  c,  'Pressed!!!!'
      state.selectedCell.write( c)
      
      userTotalRites=parseInt($("#userTotalRites").text())
      $("#userTotalRites").text(userTotalRites+1)

      cellPoint = cellKeyToXY state.selectedCell.key
      # now.writeCell(cellPoint, c)

      moveCursor(state.writeDirection)
      panIfAppropriate(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")

  inputEl.keydown (e) ->
    dbg e.which,' keydownd'
    # e.stopPropagation() # e.stopImmediatePropagation()
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
        state.selectedCell.clear()
        setSelected(state.selectedCell)
      when 13 #enter
        moveCursor 'down', state.lastClickCell
        panIfAppropriate('down')
      when 32 #space
        state.selectedCell.clear()
        moveCursor state.writeDirection
    # return false

  $("#locationSearch").submit ->
    locationString= $("#locationSearchInput").val()
    $.ajax
      url: "http://where.yahooapis.com/geocode?location=#{locationString}&flags=JC&appid=a6mq7d30"
      success: (data)->
        result =  data['ResultSet']['Results'][0]
        latlng = new L.LatLng parseFloat(result.latitude), parseFloat(result.longitude)
        dbg 'go to, ',  latlng
        map.panTo(latlng)
        $('#locationSearch').modal('hide')
    return false

  $(".modal").on 'shown', ->
    $(this).find('input')[0]?.focus()
    #end interface init
 
  $(".modal").on 'hidden', ->
    inputEl.focus()

panIfAppropriate = (direction)->
  selectedPP= $(state.selectedEl).offset()
  dbg 'selectedPP', selectedPP
  panOnDist = 200
  panByDist = state.cellHeight()
  if direction == 'up'
    if selectedPP.top < panOnDist
      pan(0, 0-panByDist)
  if direction == 'down'
    if selectedPP.top > document.body.clientHeight-panOnDist*1.5 #need to include size of a cell in state
      pan(0,panByDist)
  if direction == 'right'
      if selectedPP.left > document.body.clientWidth-panOnDist
        pan(panByDist, 0)
  if direction == 'left'
      if selectedPP.left < panOnDist
        pan(0-panByDist, 0)


jQuery ->
  # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png'
  tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/999/256/{z}/{x}/{y}.png'
  tileServeLayer = new L.TileLayer(tileServeUrl, {maxZoom: config.maxZoom()})
  centerPoint= new L.LatLng(40.714269, -74.005972)
  if not USEMAP
    window.map = new L.Map('map', {center: centerPoint, zoom: 17, scrollWheelZoom: false}) #.addLayer(tileServeLayer)
  else
    window.map = new L.Map('map', {center: centerPoint, zoom: 17, scrollWheelZoom: false}).addLayer(tileServeLayer)
  # initializeGeo()
  
  # window.domTiles = new L.TileLayer.Dom {tileSize: config.tileSize()}

  window.domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
 
  # map.locateAndSetView(17)
  # map.on 'locationfound', (e)->
  #   radius = e.accuracy / 2
  #   circle = new L.Circle(e.latlng, radius)
  #   map.addLayer(circle)
  #   return true

  now.ready ->
    now.setCurrentWorld(currentWorldId)
    map.addLayer(domTiles)
    setTileStyle() #set initial
    map.on 'zoomend', ->
      setTileStyle()
    initializeInterface()

    now.setBounds domTiles.getTilePointAbsoluteBounds()
    
    now.setClientState (s)->
      if s.color
        state.color= s.color
      else
        #easy fix for override issue, set default color. this could be random.
        state.color = 'c0'
        now.setUserOption('color','c0')
    
    $.doTimeout 500, ->
      centerCursor()
      false

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
        c.update(edit.content, edit.props)
    
    $(".trigger").live 'click', ->
      action= $(this).data('action')
      type= $(this).data('type')
      payload= $(this).data('payload')
    
      if action == 'set'
        console.log 'setting'
        state[type]=payload
        now.setUserOption(type, payload)
      return true

    now.insertMessage = (heading, message, cssclass="") ->
      html = "<div class='alert fade  #{cssclass} '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>#{heading}</h4>#{message}</div>"
      $("#messages").append(html).children().doTimeout(100, 'addClass', 'in') #.addClass('in')
      .doTimeout 5000, ->
        $(this).removeClass('in').doTimeout 300, ->$(this).alert('close').remove()

    $().alert() #applies close functionality to all alerts

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

  generateKey: ->
    @x = @tile._tilePoint.x * Math.pow(2, state.zoomDiff())+@col
    @y = @tile._tilePoint.y * Math.pow(2, state.zoomDiff())+@row
    return "c#{@x}x#{@y}"

  constructor: (@row, @col, @tile, @contents = config.defaultChar(), @props={}, @events=null) ->
    # dbg 'Cell constructor called'
    # @history = {}
    @timestamp = null #just use servertime
    @key = this.generateKey()
    all[@key]=this
    @span = document.createElement('span')
    @span.innerHTML= @contents
    @span.id= @key
    @span.className='cell '+ @props.color
    if @props.echoes
      @span.className+= " e#{props.echoes}"

  write: (c) ->
    dbg 'Cell write  called'
    @contents= c
    @span.className = 'cell '+ state.color
    @animateTextInsert(2, c)
    cellPoint = cellKeyToXY @key
    now.writeCell(cellPoint, c)

  #for updating from other users, above is for local user
  update: (contents, props)->
    dbg 'Cell update called'
    @contents= contents
    @span.innerHTML = contents
    @span.className += 'cell '+ props.color

  kill: ->
    dbg 'killing a cell'#, @key
    @span= null
    delete all[@key]

  clear: ->
    @span.innerHTML= config.defaultChar()
    @write(config.defaultChar())
    @span.className= 'cell'
  
  # this works for new text, if it's overwriting, it needs to use the one below to knock the old text out first maybe
  animateTextInsert: (animateWith=0, c) ->
    clone=  document.createElement('SPAN') #$(@span).clone().removeClass('selected')
    clone.className='cell ' + state.color
    clone.innerHTML=c
    span=@span
    $(clone).css('position', 'absolute').insertBefore('body').addClass('a'+animateWith)
    offset= $(@span).offset()
    dbg 'clone',  clone
    $(clone).css({'opacity': '1 !important', 'font-size': '1em'})
    $(clone).css({'position':'absolute', left: offset.left, top: offset.top})
    $(clone).doTimeout 400, ->
      span.innerHTML = c
      $(clone).remove()
      return false

  #rewrite this so its the clone that gets removed, which will require animationend event listeners
  cloneSpan: (animateWith=0) ->
    span= @span #the original
    clone=  $(@span).clone()
    offset= $(@span).position()#offset()
    $(@span).after(clone)
    $(@span).removeClass('selected')
    $(@span).css({'position':'absolute', left: offset.left, top: offset.top}).hide() #?
    $(@span).queue ->
      $(this).show()
      dbg 'this', this
      if animateWith
        $(this).addClass('a'+animateWith)
      $(this).dequeue()
    $(span).doTimeout 800, ->
      $(span).remove()
      return false
    @span = clone
    state.selectedEl = @span
    
  @getOrCreate:(row, col, tile, contents=null, props={}) ->
    # dbg 'cell @getOrCreate called'
    x=tile._tilePoint.x * Math.pow(2, state.zoomDiff())+col
    y=tile._tilePoint.y * Math.pow(2, state.zoomDiff())+row
    cell=Cell.get(x,y)
    if cell
      return cell
    else
      cell = new Cell row, col, tile, contents, props
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
