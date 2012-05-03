window.state =
  selectedCell: null
  lastClickCell: null #actually more about carriage return
  color: null
  # geoPos: null
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
  belowInputRateLimit: true
  topLayerStamp: null
  baseLayer: null
  cursors: {}

setTileStyle = ->
 width = state.cellWidth()
 height = state.cellHeight()
 fontSize = height*0.9 #width*1.5 #why not
 rules = []
 rules.push("div.leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 $("#dynamicStyles").text rules.join("\n")

# TODO rewrite with command pattern, and big otherUsers object
window.setCursor = (cell) ->  # takes the object, not the dom element
  dbg 'selecting', cell
  if state.selectedEl
    $(state.selectedEl).removeClass('selected')
  state.selectedEl=cell.span
  $(cell.span).addClass('selected')
  state.selectedCell =cell
  now.setCursor cellKeyToXY cell.key
 
  if cell.props
    if cell.props.decayed
     cell.animateTextRemove(1)
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
  else
    panIfAppropriate(direction)
    setCursor(targetCell)
    return targetCell

window.centerCursor = ->
  $.doTimeout 400, ->
    # target = window.domTiles.getCenterTile()
    console.log state.topLayerStamp
    layer=getLayer(state.topLayerStamp)
    if not layer
      return true
    target=layer.getCenterTile()
    # console.log('center cursor poll')
    key = "c#{target.x}x#{target.y}"
    targetCell=Cell.all()[key]
    if not targetCell
      return true #true to repeat the timer and try again
    else
      setCursor(targetCell)
      return false
    true

#INTERFACE INITIALIZER 
initializeInterface = ->
  dbg 'initializing interface'
  $("#map").click (e) ->
    # console.log e.target
    if $(e.target).hasClass 'cell'
      cell=Cell.all()[e.target.id]
      state.lastClickCell = cell
      setCursor(cell)
      inputEl.focus()
    else
      inputEl.focus()
      return false

  window.inputEl = $ "#input"
  inputEl.focus()

  map.on 'zoomend', ->
    inputEl.focus()

  map.on 'viewreset', (e) ->
    $("#loadingIndicator").fadeIn('fast')
    if map.getZoom() >= config.minLayerZoom() and not state.topLayerStamp
      turnOnMainLayer() #should be turnOnLastLayer 
  
  map.on 'dblclick', (e) ->
    $("#loadingIndicator").fadeIn('fast')

  $(".leaflet-control-zoom-in, .leaflet-control-zoom-out").click (e) ->
    $("#loadingIndicator").fadeIn('fast')

  inputEl.keypress (e) ->
    dbg  e.which, 'pressed'
    console.log e.which
    if e.which in [0, 13, 32, 9, 8] # 40, 39, 38  were here, but that seems to be single quote?
      console.log 'SPECIAL KEY, screw this keypress'
      return false
    else #it's a normal character which we should actually write
      c = String.fromCharCode e.which
      dbg  c,  'Pressed!!!!'
      state.selectedCell.write( c)
      
      userTotalRites=parseInt($("#userTotalRites").text())
      $("#userTotalRites").text(userTotalRites+1)

      cellPoint = cellKeyToXY state.selectedCell.key

      moveCursor(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")

  inputEl.keydown (e) ->
    dbg e.which,' keydownd'
    # e.stopPropagation() # e.stopImmediatePropagation()

    if not (state.belowInputRateLimit)
      return false
    state.belowInputRateLimit = false
    $.doTimeout 'keydownlimit', config.inputRateLimit(), ->
      state.belowInputRateLimit =true
      return false

    switch e.which
      when 9 #tab
        e.preventDefault()
        return false
      when 38
        moveCursor('up')
      when 40
        moveCursor('down')
      when 39
        moveCursor('right')
      when 37
        moveCursor('left')
      when 8 # delete
        moveCursor 'left'
        state.selectedCell.clear()
        setCursor(state.selectedCell)
      when 13 #enter
        t = moveCursor 'down', state.lastClickCell
        state.lastClickCell = t
      when 32 #space
        state.selectedCell.clear()
        moveCursor state.writeDirection
    # return false

  # todo limit 
  $("#locationSearch").submit ->
    locationString= $("#locationSearchInput").val()
    $.ajax
      url: "http://where.yahooapis.com/geocode?location=#{locationString}&flags=JC&appid=a6mq7d30"
      success: (data)->
        console.log data
        result =  data['ResultSet']['Results'][0]
        latlng = new L.LatLng parseFloat(result.latitude), parseFloat(result.longitude)
        dbg 'go to, ',  latlng
        map.panTo(latlng)
        $('#locationSearch').modal('hide')
        centerCursor()
    return false

  $(".modal").on 'shown', ->
    $(this).find('input')[0]?.focus()
 
  $(".modal").on 'hidden', ->
    inputEl.focus()

  $(".leaflet-control-zoom-in").click (e) ->
    map.zoomIn()
    return

  $(".leaflet-control-zoom-out").click (e) ->
    if map.getZoom() <=config.minLayerZoom() and state.topLayerStamp
      removeLayerThenZoomOut()
    else
      map.zoomOut()
    return

  $(".trigger").live 'click', ->
    action= $(this).data('action')
    type= $(this).data('type')
    payload= $(this).data('payload')
    text = $(this).text()
    console.log text
    $(this).parent().parent().find('.active').removeClass('active')
    $(this).parent().addClass('active')
    console.log 'trigger triggered'

    if action == 'set' #change this (and setUserOption below) setServerState
      state[type]=payload
      now.setUserOption(type, payload)
    if action == 'setClientState' # unrelated to setClientStateFromServer 
      # console.log 'settingClientState', type
      state[type] = payload
    
    
    #specific interfaces

    # Layer Switching
    if type=='layer'
      $("#worldLayer").html(text+'<b class="caret"></b>' )
      if payload=='off' and state.topLayerStamp
        turnOffLayer()
      else if payload=='main'
        turnOnMainLayer()
      else
        switchToLayer(payload)

    if type == 'color'
      # console.log 'ch color'
      $("#color").addClass(payload)
    if type == 'writeDirection'
      c= this.innerHTML
      $('.direction-dropdown')[0].innerHTML=c
      $('.direction-dropdown i').addClass('icon-white')
    if type == 'submitfeedback'
      f=$('#feedback').val()
      t=$("#t").val()
      now.submitFeedback(f,t)
      $('#feedbackModal').modal('hide')
      inputEl.focus()
      return false
    inputEl.focus()
    return


panIfAppropriate = (direction)->
  selectedPP= $(state.selectedEl).offset()
  dbg 'selectedPP', selectedPP
  panOnDist = 200
  if direction is 'left' or direction is 'right'
    panByDist = state.cellWidth()
  else
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
  tileServeLayer = new L.TileLayer(config.tileServeUrl(), {maxZoom: config.maxZoom()})
  state.baseLayer= tileServeLayer

  centerPoint= new L.LatLng(40.714269, -74.005972) 
  mapOptions =
    center: centerPoint
    zoomControl: false
    attributionControl:false
    zoom: config.defZoom()
    scrollWheelZoom: false
    minZoom: config.minZoom()
    maxZoom: config.maxZoom()-window.MapBoxBadZoomOffset 
  window.map= new L.Map('map', mapOptions).addLayer(tileServeLayer)

  initializeGeo()
  
  domTiles = new L.DomTileLayer {tileSize: config.tileSize()}

  # state.topLayer = domTiles
  state.topLayerStamp = L.Util.stamp domTiles

  now.ready ->
    now.setCurrentWorld(initialWorldId)
    map.addLayer(domTiles)
    setTileStyle() #set initial
    map.on 'zoomend', ->
      setTileStyle()
    initializeInterface()
    $("#loadingIndicator").fadeOut('slow')
    
    now.setBounds domTiles.getTilePointAbsoluteBounds()
      
    map.on 'moveend', (e)->
      now.setBounds getLayer(state.topLayerStamp).getTilePointAbsoluteBounds() if state.topLayerStamp
      $("#loadingIndicator").fadeOut('slow')
    map.on 'zoomend', (e)->
      now.setBounds getLayer(state.topLayerStamp).getTilePointAbsoluteBounds() if state.topLayerStamp
      $("#loadingIndicator").fadeOut('slow')

    now.setClientStateFromServer (s)->
      if s.color # s is session
        state.color= s.color
      else #easy fix for override issue, set default color. this could be random.
        state.color = 'c0'
        now.setUserOption('color','c0')

    centerCursor()


    now.updateCursors = (updatedCursor) ->
      if state.cursors[updatedCursor.cid]
        cursor=state.cursors[updatedCursor.cid]
        selectedCell = Cell.get(cursor.x, cursor.y)
        $(selectedCell.span).removeClass("c#{cursor.color} otherSelected")
      state.cursors[updatedCursor.cid]= updatedCursor
      cursor= updatedCursor
      if cursor.x and cursor.y
        selectedCell = Cell.get(cursor.x, cursor.y)
        $(selectedCell.span).addClass("c#{cursor.color} otherSelected")
      else
        delete state.cursors[cursor.cid] # on disconnect, remove
  
    $("#getNearby").click ->
      now.getCloseUsers (closeUsers)->
        console.log closeUsers
        $("#nearby").empty()
        if closeUsers.length is 0
          $("ul#nearby").append -> $ '<li> <a>Sorry, no one is nearby. </a></li>'
          return false
        cellPoint=cellKeyToXY state.selectedCell.key
        for user in closeUsers
          user.radians=Math.atan2(cellPoint.y-user.cursor.y, cellPoint.x-user.cursor.x) #y,x
          user.degrees= user.radians*(180/Math.PI)
          if user.radians < 0
            user.degrees= 360+user.degrees #this ends up with directly left =0, up being 90 and so on
          if not user.login
            user.login= 'Someone'
          $("ul#nearby").append ->
            arrow= $("<li><a><i class='icon-arrow-left' style='-moz-transform: rotate(#{user.degrees}deg);-webkit-transform: rotate(#{user.degrees}deg);'></i> #{user.login}</a></li>")
        true

    now.drawRite = (commandType, rite, cellPoint, cellProps) ->
      # console.log(commandType, rite, cellPoint)
      c=Cell.get(cellPoint.x, cellPoint.y)
      c[commandType](rite, cellProps)

    now.insertMessage = (heading, message, cssclass) ->
      insertMessage(heading, message, cssclass)

    return # end now.ready


  return true # end doc.ready


# this shouldn't get called until docready anyway...
window.insertMessage = (heading, message, cssclass="", timing=6 ) ->
  html = "<div class='alert alert-block fade  #{cssclass} '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>#{heading}</h4>#{message}</div>"
  if timing > 0
    $("#messages").append(html).children().doTimeout(100, 'addClass', 'in')
      .doTimeout timing*1000, ->
        $(this).removeClass('in').doTimeout 300, -> $(this).alert('close').remove()
  else
    $("#messages").append(html).children().doTimeout(100, 'addClass', 'in')

window.clearMessages = ->
  $("#messages").children().removeClass('in').doTimeout 300, ->
    $(this).alert('close').remove()
  true


$().alert() #applies close functionality to all alerts

#todo disable cell caching, because then they don't get liveupdated when not visible, duh...

window.Cell = class Cell
  all = {}
  @all: -> all
  @get: (x,y) ->
    return all["c#{x}x#{y}"]

  @killAll: ->
    all={}

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
    
    @key = this.generateKey()
    all[@key]=this
    @span = document.createElement('span')
    @span.innerHTML= @contents
    @span.id= @key
    $(@span).addClass('cell')
    if not @props.color
      @props.color = 'c0'
    $(@span).addClass(@props.color)
    if @props.echoes
      $(@span).addClass("e#{@props.echoes}")
    
    @watch "contents", (id, oldval, newval) ->
      @span.innerHTML=newval
      return newval

    $span = $(@span)
    @props.watch "echoes", (id, oldval, newval) ->
      # console.log "echoes changed, #{oldval} to #{newval}"
      # console.log $span 
      $span.removeClass('e'+oldval)
      $span.addClass('e'+newval)
      return newval

    @props.watch "color", (id, oldval, newval) ->
      # console.log "color changed, #{oldval} to #{newval}"
      # console.log $span 
      $span.removeClass(oldval)
      $span.addClass(newval)
      return newval

  write: (c) ->
    cellPoint = cellKeyToXY @key
    now.writeCell(cellPoint,c)
    # TODO this is so simple, but really we should be handling this client side. lag will be frustrating.

  # COMMAND PATTERN
  normalRite: (rite) ->
    @contents = rite.contents
    @props.color= rite.props.color

  echo: (rite, cellProps) ->
    @props.echoes = cellProps.echoes
    @animateText(1)
    @props.color= cellProps.color

  overrite: (rite, cellProps) ->
    @animateTextRemove(1)
    @contents = rite.contents
    @props.echoes =0
    @props.color= rite.props.color

  downrote: (rite, cellProps) ->
    $(@span).removeClass('e'+@props.echoes)
    @props.echoes-=1
    @props.color= cellProps.color
    shakeWindow(1)

  kill: ->
    dbg 'killing a cell'#, @key
    @span= null
    delete all[@key]
    
  clear: ->
    @write(config.defaultChar())
  
  animateTextInsert: (animateWith=0, c) ->
    if not prefs.animate.writing
      @span.innerHTML = c
      return
    clone=  document.createElement('SPAN') #$(@span).clone().removeClass('selected')
    clone.className='cell ' + state.color
    clone.innerHTML=c
    span=@span
    $(clone).css('position', 'absolute').insertBefore('body').addClass('ai'+animateWith)
    offset= $(@span).offset()
    dbg 'clone',  clone
    $(clone).css({'opacity': '1 !important', 'font-size': '1em'})
    $(clone).css({'position':'absolute', left: offset.left, top: offset.top})
    $(clone).doTimeout 200, ->
      span.innerHTML = c
      $(clone).remove()
      return false
  
  animateText: (animateWith=0) ->
    span= @span #the original
    clone=  $(@span).clone()
    offset= $(@span).position()#offset()
    $(@span).after(clone)
    $(clone).removeClass('selected')
    $(clone).addClass('aa').css({'position':'absolute', left: offset.left, top: offset.top}).hide() #?
    $(clone).queue ->
      # $(this).show().css({'fontSize':'+=90', 'marginTop': -state.cellHeight()/2, 'marginLeft': -state.cellWidth()/2})
      $(this).show().css({'fontSize':'+=90' , 'marginTop': "-=45", 'marginLeft': "-=45"})
      # $(this).addClass('aa'+animateWith)
      $(this).dequeue()
    $(clone).doTimeout 400, ->
      # $(clone).removeClass('aa'+animateWith)
      $(this).css({'fontSize':'-=90', 'marginTop': 0, 'marginLeft': 0})
      this.doTimeout 400, ->
        $(span).show()
        $(clone).remove()
      return false

  animateTextRemove: (animateWith=0) ->
    span= @span #the original
    clone=  $(@span).clone()
    @span.innerHTML= config.defaultChar()
    offset= $(@span).position()#offset()
    $(@span).after(clone)
    $(clone).removeClass('selected')
    $(clone).css({'position':'absolute', left: offset.left, top: offset.top}).hide() #?
    $(clone).queue ->
      $(this).show()
      dbg 'this', this
      if animateWith
        $(this).addClass('ar'+animateWith)
      $(this).dequeue()
    $(clone).doTimeout 800, ->
      $(clone).remove()
      return false
    
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


removeLayerThenZoomOut=  ->
  Cell.killAll()
  layer= map._layers[state.topLayerStamp]
  $layer = $(".layer-#{state.topLayerStamp}")
  $layer.fadeOut('slow')
  console.log 'turn off layer'
  map.removeLayer(layer) if state.topLayerStamp
  state.topLayerStamp = 0
  now.setCurrentWorld(null)
  map.zoomOut()
  return


turnOffLayer = ->
  #hide the layer first, with css?
  Cell.killAll()
  layer= map._layers[state.topLayerStamp]
  $layer = $(".layer-#{state.topLayerStamp}")
  $layer.fadeOut('slow')
  $.doTimeout 500, ->
    console.log 'turn off layer'
    map.removeLayer(layer) if state.topLayerStamp
    state.topLayerStamp = 0
    now.setCurrentWorld(null)
    return false
  return

turnOnMainLayer= ->
  console.log 'turn on layer'
  Cell.killAll()
  # map.removeLayer(state.topLayer) if state.topLayer
  now.setCurrentWorld(mainWorldId)
  domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
  map.addLayer(domTiles)
  stamp= L.Util.stamp(domTiles)
  console.log 'stamp', stamp
  state.topLayerStamp = stamp
  now.setBounds domTiles.getTilePointAbsoluteBounds()
  inputEl.focus()
  centerCursor()

switchToLayer= (worldId) ->
  #todo load ruleset/config from now
  Cell.killAll()
  map.removeLayer(getLayer(state.topLayerStamp)) if state.topLayerStamp
  now.setCurrentWorld(worldId)
  domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
  map.addLayer(domTiles)
  state.topLayerStamp = L.Util.stamp domTiles
  now.setBounds domTiles.getTilePointAbsoluteBounds()
  inputEl.focus()
  centerCursor()

getLayer = (stamp) ->
  return map._layers[stamp]


window.shakeWindow =(s=1) ->
  b = $('body') #s = severity
  options =
    x: 2+s/2
    y: 2+s/2
    rotation: s/2
    speed: 18-s*3

  b.jrumble(options)
  b.trigger('startRumble')
  b.doTimeout 500, ->
    b.trigger('stopRumble')
    false
  true
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
