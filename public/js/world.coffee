window.state =
  selectedCell: null
  lastClickCell: null #actually more about carriage return
  color: null
  # canRead: true
  # canWrite: true
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

#NOTE: Scroll Timer Code to get rid of address bar on mobile/ios is in client_config

setTileStyle = ->
 width = state.cellWidth()
 height = state.cellHeight()
 fontSize = height*0.9 #width*1.5 #why not
 rules = []
 rules.push("div.leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 $("#dynamicStyles").text rules.join("\n")

window.setSelected = (cell) ->  # takes the object, not the dom element
  dbg 'selecting', cell
  if state.selectedEl
    $(state.selectedEl).removeClass('selected')
  state.selectedEl=cell.span
  $(cell.span).addClass('selected')
  state.selectedCell =cell
  now.setSelectedCell cellKeyToXY cell.key
 
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
    setSelected(targetCell)
    return targetCell

window.centerCursor = ->
  $.doTimeout 400, ->
    target = window.domTiles.getCenterTile()
    # console.log('center cursor poll')
    key = "c#{target.x}x#{target.y}"
    targetCell=Cell.all()[key]
    if not targetCell
      return true #true to repeat the timer and try again
    else
      setSelected(targetCell)
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
      # console.log 'SPECIAL KEY, screw this keypress'
      return false
    else #it's a normal character which we should actually write
      c = String.fromCharCode e.which
      # console.log  c,  'Pressed!!!!'
      state.selectedCell.write( c)
      
      userTotalRites=parseInt($("#userTotalRites").text())
      $("#userTotalRites").text(userTotalRites+1)

      cellPoint = cellKeyToXY state.selectedCell.key
      # now.writeCell(cellPoint, c)

      moveCursor(state.writeDirection)
      # panIfAppropriate(state.writeDirection)

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
        # panIfAppropriate('up')
      when 40
        moveCursor('down')
        # panIfAppropriate('down')
      when 39
        moveCursor('right')
        # panIfAppropriate('right')
      when 37
        moveCursor('left')
        # panIfAppropriate('left')
      when 8
        moveCursor('left')
        # panIfAppropriate('left')
        state.selectedCell.clear()
        setSelected(state.selectedCell)
      when 13 #enter
        t = moveCursor 'down', state.lastClickCell
        state.lastClickCell = t
        # panIfAppropriate('down')
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
        centerCursor()

    return false

  $(".modal").on 'shown', ->
    $(this).find('input')[0]?.focus()
    #end interface init
 
  $(".modal").on 'hidden', ->
    inputEl.focus()


  $(".trigger").live 'click', ->
    action= $(this).data('action')
    type= $(this).data('type')
    payload= $(this).data('payload')
    console.log 'trigger triggered'
    if action == 'set' #change this (and setUserOption below) setServerState
      state[type]=payload
      now.setUserOption(type, payload)
    if action == 'setClientState' # unrelated to setClientStateFromServer 
      # console.log 'settingClientState', type
      state[type] = payload
    
    #specific interfaces

    if type == 'color'
      # console.log 'ch color'
      $("#color").addClass(payload)
      inputEl.focus()
    if type == 'writeDirection'
      c= this.innerHTML
      $('.direction-dropdown')[0].innerHTML=c
      $('.direction-dropdown i').addClass('icon-white')
      inputEl.focus()
    if type == 'submitfeedback'
      f=$('#feedback').val()
      now.submitFeedback(f)
      $('#feedbackModal').modal('hide')
      return false
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
  # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/997/256/{z}/{x}/{y}.png'
  tileServeUrl = 'http://ec2-107-20-56-118.compute-1.amazonaws.com/tiles/tiles.py/wwtiles/{z}/{x}/{y}.png'
  # tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/999/256/{z}/{x}/{y}.png'
  tileServeLayer = new L.TileLayer(tileServeUrl, {maxZoom: config.maxZoom()})
  centerPoint= new L.LatLng(40.714269, -74.005972) #try adding slight randomness to this
  window.map = new L.Map('map', {center: centerPoint, zoom: config.defZoom(), scrollWheelZoom: false, minZoom: config.minZoom(), maxZoom: config.maxZoom() }).addLayer(tileServeLayer)
  initializeGeo()
  
  # window.domTiles = new L.TileLayer.Dom {tileSize: config.tileSize()}
  window.domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
 
  now.ready ->
    now.setCurrentWorld(currentWorldId)
    map.addLayer(domTiles)
    setTileStyle() #set initial
    map.on 'zoomend', ->
      setTileStyle()
    initializeInterface()

    now.setBounds domTiles.getTilePointAbsoluteBounds() #this seems to be buggy on iOS
    
    map.on 'moveend', (e)->
      now.setBounds domTiles.getTilePointAbsoluteBounds()
    map.on 'zoomend', (e)->
      now.setBounds domTiles.getTilePointAbsoluteBounds()

    now.setClientStateFromServer (s)->
      if s.color
        state.color= s.color
      else
        #easy fix for override issue, set default color. this could be random.
        state.color = 'c0'
        now.setUserOption('color','c0')

    centerCursor()
    
    now.drawCursors = (user) ->
      # TODO Fix this up: make it a global object 
      # console.log user, 'users'
      $(".u#{user.cid}").removeClass("otherSelected u#{user.cid} c#{user.color}")

      if user.selected.x
        otherSelected = Cell.get(user.selected.x, user.selected.y)
        if otherSelected
          $(otherSelected.span).addClass("u#{user.cid} c#{user.color} otherSelected")
    
    
    $("#getNearby").click ->
      now.getCloseUsers (closeUsers)->
        $("#nearby").empty()
        cellPoint=cellKeyToXY state.selectedCell.key
        for user in closeUsers
          user.radians=Math.atan2(cellPoint.y-user.selected.y, cellPoint.x-user.selected.x) #y,x
          user.degrees= user.radians*(180/Math.PI)
          if user.radians < 0
            user.degrees= 360+user.degrees #this ends up with directly left =0, up being 90 and so on
          if not user.name
            user.name= 'Someone'
          $("ul#nearby").append ->
            arrow= $("<li><a><i class='icon-arrow-left' style='-moz-transform: rotate(#{user.degrees}deg);-webkit-transform: rotate(#{user.degrees}deg);'></i> #{user.name}</a></li>")
        true

    now.drawEdits = (edits) ->
      # console.log edits
      for id, edit of  edits
        c=Cell.get(edit.cellPoint.x, edit.cellPoint.y)
        if c
          c.update(edit.content, edit.props)

    now.insertMessage = (heading, message, cssclass) ->
      insertMessage(heading, message, cssclass)

    true # end now.ready

  true # end doc.ready


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
    if not @props.color
      @props.color = 'c0'
    @span.className='cell '+ @props.color
    if @props.echoes
      @span.className+= " e#{@props.echoes}"

  write: (c) ->
    if (@contents == c) and (@props.youCanEcho isnt false) #an echo!
      @animateText(1)
      if @props.echoes
          echoes = @props.echoes+1
      else
          echoes =1
      $(@span).addClass('e'+echoes)

    else if @props.youCanEcho is false and (@contents is c) # a user echoing something they've already echoed or written themselves
      return false

    else  #all other rites
      if @props.echoes >= 1
        $(@span).removeClass('e'+@props.echoes)
        @props.echoes = @props.echoes-1
        $(@span).addClass("e#{@props.echoes}")
        shakeWindow()
        cellPoint = cellKeyToXY @key
        now.writeCell(cellPoint, c)
        @props.youCanEcho = false
        return
      # if @props.youCanEcho == false #this won't work, it prevents you from writing over things you've written
        # return false

      if @contents
        @animateTextRemove(1)
      @contents= c
      @span.className = 'cell '+ state.color
    
      n= Math.ceil(Math.random()*10)%3+1 # console.log n
      @animateTextInsert(n, c)

    @props.youCanEcho = false
    cellPoint = cellKeyToXY @key
    now.writeCell(cellPoint, c)

  #for updating from other users, above is for local user
  update: (contents, props)->
    dbg 'Cell update called'
    @contents= contents
    @span.innerHTML = contents
    @span.className = 'cell '+ props.color

  kill: ->
    dbg 'killing a cell'#, @key
    @span= null
    delete all[@key]
    
  clear: ->
    if @contents
      @animateTextRemove(1)
    @span.innerHTML= config.defaultChar()
    @write(config.defaultChar())
    @span.className= 'cell'
  
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
