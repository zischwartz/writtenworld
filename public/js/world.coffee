window.state =
  selectedCell: null
  lastClickCell: null #actually more about carriage return
  color: null
  geoPos: null
  geoAccuracy: null
  writeDirection: 'right'
  zoomDiff: ->
    config.maxZoom()-map.getZoom()
  numRows: ->
    numRows = Math.pow(2, state.zoomDiff())
  numCols: ->
    numCols = Math.pow(2, state.zoomDiff())
  cellWidth: ->
    config.tileSize().x/state.numCols()
  cellHeight: ->
    config.tileSize().y/state.numRows()
  belowInputRateLimit: true
  topLayerStamp: null
  baseLayer: null
  lastLayerStamp: null
  isTopLayerInteractive: true
  cursors: {}
  isLocal: true

setTileStyle = ->
 width = state.cellWidth()
 height = state.cellHeight()
 fontSize = height*0.9
 rules = []
 rules.push("div.leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 $("#dynamicStyles").text rules.join("\n")

window.setCursor = (cell) ->  # takes the object, not the dom element
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


moveCursor = (direction, from = state.selectedCell, force=false) ->
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
    if config.autoPan() or force
      panIfAppropriate(direction)
    setCursor(targetCell)
    return targetCell

window.centerCursor = ->
  $.doTimeout 400, ->
    # target = window.domTiles.getCenterTile()
    # console.log state.topLayerStamp
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
      state.lastClickCell = targetCell
      return false
    true

#INTERFACE INITIALIZER 
initializeInterface = ->
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
      #TODO

  map.on 'dblclick', (e) ->
    $("#loadingIndicator").fadeIn('fast')

  $(".leaflet-control-zoom-in, .leaflet-control-zoom-out").click (e) ->
    $("#loadingIndicator").fadeIn('fast')

  inputEl.keypress (e) ->
    # console.log e.which
    if not state.isTopLayerInteractive
      return false
    if e.which in [0, 13, 32, 9, 8] # 40, 39, 38  were here, but that seems to be single quote?
      # console.log 'SPECIAL KEY, screw this keypress'
      return false
    else
      c = String.fromCharCode e.which
      state.selectedCell.write( c)

      userTotalRites=parseInt($("#userTotalRites").text())
      $("#userTotalRites").text(userTotalRites+1)
      # cellPoint = cellKeyToXY state.selectedCell.key

      moveCursor(state.writeDirection)

    # inp = String.fromCharCode(event.keyCode)
    # if (/[a-zA-Z0-9-_ ]/.test(inp))
      # console.log("input was a letter, number, hyphen, underscore or space")

  inputEl.keydown (e) ->
    # e.stopPropagation() # e.stopImmediatePropagation()

    if not state.isTopLayerInteractive
      return false

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
        moveCursor('up', null, true)
      when 40
        moveCursor('down', null, true)
      when 39
        moveCursor('right', null, true)
      when 37
        moveCursor('left', null, true)
      when 8 # delete
        moveCursor 'left' , null
        state.selectedCell.clear()
        setCursor(state.selectedCell)
      when 13 #enter
        t = moveCursor 'down', state.lastClickCell, true
        state.lastClickCell = t
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
        km=latlng.distanceTo(state.geoPos)/1000
        # console.log km
        # console.log state.userPowers.jumpDistance
        # if km <= state.userPowers.jumpDistance
        if km<=config.maxJumpDistance()
          map.panTo(latlng)
          state.geoPos= latlng
        else if config.isAuth()
          state.isLocal = false
          map.panTo(latlng)
          state.geoPos= latlng
          now.isLocal= false
        else
          insertMessage('Too Far!', "Sorry, you can't jump that far. Signup to go further than #{config.maxJumpDistance()} km.")
        $('#locationSearch').modal('hide')
        centerCursor()
    return false

  $(".modal").on 'shown', ->
    $(this).find('input')[0]?.focus()
 
  $(".modal").on 'hidden', ->
    inputEl.focus()

  $(".leaflet-control-zoom-in").click (e) ->
    if map.getZoom() ==config.maxZoom()
        insertMessage('Zoomed In', "That's as far as you can zoom out right now..")
        $("#loadingIndicator").fadeOut('slow')
        return false
    map.zoomIn()
    return

  $(".leaflet-control-zoom-out").click (e) ->
    if map.getZoom() ==config.minZoom()
        insertMessage('Zoomed Out', "That's as far as you can zoom out right now..")
        $("#loadingIndicator").fadeOut('slow')
        return false
    if map.getZoom() <=config.minLayerZoom() and state.isTopLayerInteractive 
        removeLayerThenZoomAndReplace()
        insertMessage('No Writing', " You've zoomed out too far to write. The text density is now represented by circles. Zoom back in to read and write again.")
        # console.log 'zoomout replace'
    else
      map.zoomOut()
      # console.log 'just zoomout'
    return

  $(".trigger").live 'click', ->
    action= $(this).data('action')
    type= $(this).data('type')
    payload= $(this).data('payload')
    text = $(this).text()
    # console.log text
    $(this).parent().parent().find('.active').removeClass('active')
    $(this).parent().addClass('active')
    # console.log 'trigger triggered'

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

  $("#welcome").doTimeout 15000, ->
    $("#welcome").fadeOut()

  tileServeLayer = new L.TileLayer(config.tileServeUrl(), {maxZoom: config.maxZoom()})
  state.baseLayer= tileServeLayer

  centerPoint= new L.LatLng(40.714269, -74.005972)
  mapOptions =
    center: centerPoint
    zoomControl: false
    attributionControl:false
    zoom: config.defZoom()
    scrollWheelZoom: config.scrollWheelZoom()
    minZoom: config.minZoom()
    maxZoom: config.maxZoom()-window.MapBoxBadZoomOffset
  window.map= new L.Map('map', mapOptions).addLayer(tileServeLayer)
  
  initializeGeo()

  now.ready ->
    doNowInit(now)
    # now.core.socketio.on 'reconnect', ->
    #   console.log 'reconnected!'
    return # end now.ready

  return true # end doc.ready

doNowInit= (now)->
    domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
    state.topLayerStamp = L.Util.stamp domTiles
    now.isLocal= state.isLocal

    now.setCurrentWorld(initialWorldId, personalWorldId)
    map.addLayer(domTiles)
    setTileStyle() #set initial
    map.on 'zoomend', ->
      setTileStyle()
    initializeInterface()
    $("#loadingIndicator").fadeOut('slow')
    
    now.setBounds domTiles.getTilePointAbsoluteBounds()
  
    now.core.socketio.on 'disconnect', ->
      $("#errorIndicator").fadeIn('fast')
      $.doTimeout 2000, ->
        location.reload()

    map.on 'moveend', (e)->
      now.setBounds getLayer(state.topLayerStamp).getTilePointAbsoluteBounds() if state.topLayerStamp
      $("#loadingIndicator").fadeOut('slow')

    map.on 'zoomend', (e)->
      if state.topLayerStamp
        now.setBounds getLayer(state.topLayerStamp).getTilePointAbsoluteBounds()
      if map.getZoom()==config.minLayerZoom() and state.topLayerStamp and not state.isTopLayerInteractive
        # console.log 'ZOOMIN SWITCH'
        turnOffLayer()
        turnOnMainLayer()
        $("#loadingIndicator").fadeOut('slow')

    now.setClientStateFromServer (s)->
      state.userPowers = s.powers
      if s.color # s is session
        state.color= s.color
      else #easy fix for override issue, set default color. this could be random.
        color_ops = ['c0', 'c1', 'c2', 'c3']
        state.color=color_ops[ Math.floor(Math.random() * 4)]
        # state.color = 'c0'
        now.setUserOption('color',state.color)
      
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
        # console.log closeUsers
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
## END doNowInit()

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
    now.writeCell(cellPoint, c)
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
      if animateWith
        $(this).addClass('ar'+animateWith)
      $(this).dequeue()
    $(clone).doTimeout 800, ->
      $(clone).remove()
      return false
    
  @getOrCreate:(row, col, tile, contents=null, props={}) ->
    x=tile._tilePoint.x * Math.pow(2, state.zoomDiff())+col
    y=tile._tilePoint.y * Math.pow(2, state.zoomDiff())+row
    cell=Cell.get(x,y)
    if cell
      return cell
    else
      cell = new Cell row, col, tile, contents, props
      return cell

#LAYER SWITCH CODE
removeLayerThenZoomOut=  ->
  Cell.killAll() #this is good, but not actually neccesary (noted, because it used to be neccesary)
  layer= map._layers[state.topLayerStamp]
  $layer = $(".layer-#{state.topLayerStamp}")
  $layer.fadeOut('slow')
  # console.log 'turn off layer'
  map.removeLayer(layer) if state.topLayerStamp
  state.topLayerStamp = 0
  now.setCurrentWorld(null)
  map.zoomOut()
  return

removeLayerThenZoomAndReplace = ->
  Cell.killAll()
  layer= map._layers[state.topLayerStamp]
  $layer = $(".layer-#{state.topLayerStamp}")
  $layer.fadeOut('slow')
  map.removeLayer(layer) if state.topLayerStamp
  map.zoomOut()

  canvasTiles = new L.WCanvas({tileSize:{x:192, y:256}})

  map.addLayer canvasTiles
  state.isTopLayerInteractive= false
  stamp= L.Util.stamp(canvasTiles)

  # now.setBounds canvasTiles.getTilePointAbsoluteBounds()
  now.setBounds false 
  state.topLayerStamp = stamp
  return true


turnOffLayer = ->
  #hide the layer first, with css?
  Cell.killAll()
  layer= map._layers[state.topLayerStamp]
  $layer = $(".layer-#{state.topLayerStamp}")
  $layer.fadeOut('slow')
  $.doTimeout 500, ->
    # console.log 'turn off layer'
    map.removeLayer(layer) if state.topLayerStamp
    # state.topLayerStamp = 0
    # now.setCurrentWorld(null)
    return false
  return

turnOnMainLayer= ->
  # console.log 'turn on layer'
  Cell.killAll()
  now.setCurrentWorld(initialWorldId, personalWorldId)
  # now.setCurrentWorld(mainWorldId, personalWorldId)
  domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
  map.addLayer(domTiles)
  stamp= L.Util.stamp(domTiles)
  state.topLayerStamp = stamp
  state.isTopLayerInteractive= true
  now.setBounds domTiles.getTilePointAbsoluteBounds()
  inputEl.focus()
  centerCursor()



#not used
switchToLayer= (worldId) ->
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
