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

  topLayerStamp: null #assigning in init to domtiles
  lastLayerStamp: null
  isTopLayerInteractive: true
  
  cursors: {}
  isLocal: true
  # belowInputRateLimit: true
  belowArrowKeyRateLimit: true
  linkurl:false

setTileStyle = ->
 width = state.cellWidth()
 height = state.cellHeight()
 fontSize = height*0.9
 rules = []
 # rules.push("div.leaflet-tile span { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 rules.push(".cell { width: #{width}px; height: #{height}px; font-size: #{fontSize}px;}")
 $("#dynamicStyles").text rules.join("\n")

# just yr cursor
window.setCursor = (cell) ->  # takes the object, not the dom element
  if state.selectedEl
    $(state.selectedEl).removeClass('selected')
  state.selectedEl=cell.span
  $(cell.span).addClass('selected')
  state.selectedCell =cell
  now.setCursor cellKeyToXY cell.key
  # if cell.props?.decayed
  #  cell.animateTextRemove(1)
  return true

moveCursor = (direction, from = state.selectedCell, force=false, arrowKey=false) ->
  if arrowKey
    if not (state.belowArrowKeyRateLimit)
      return false
    state.belowArrowKeyRateLimit = false
    $.doTimeout 'keydownlimit', config.inputRateLimit(), ->
      state.belowArrowKeyRateLimit =true
      return false

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
      panIfAppropriate(direction, force)
    setCursor(targetCell)
    return targetCell

window.centerCursor = ->
  $.doTimeout 400, ->
    if state.selectedCell and $(".selected").length
      inputEl.focus()
      return false # they clicked and set it themselves, so don't center it
    layer=getLayer(state.topLayerStamp)
    if not layer
      return true
    target=layer.getCenterTile()
    key = "c#{target.x}x#{target.y}"
    targetCell=Cell.all()[key]
    if not targetCell
      return true #true to repeat the timer and try again
    else
      setCursor(targetCell)
      state.lastClickCell = targetCell
      inputEl.focus()
      $('.leaflet-tile a').tooltip({placement:'top'})
      return false
  return true

#INTERFACE INITIALIZER 
initializeInterface = ->

  $("#map").click (e) ->
    # console.log e.target
    if $(e.target).hasClass 'cell'
      cell=Cell.all()[e.target.id]
      state.lastClickCell = cell
      setCursor(cell)
      inputEl.focus()
      return false
    else if e.target.href
      return true
    else
      inputEl.focus()
      return false

  window.inputEl = $ "#input"
  inputEl.focus()
  $('.navbar a').tooltip({placement:'bottom'})

  map.on 'zoomend', ->
    inputEl.focus()
    $("#loadingIndicator").fadeOut('fast')
  
  $userTotalRites = $("#userTotalRites")

  colorselectcounter=0
  $("#colorPicker").colorpicker
    realtime: false
    color: config.colorOptions[ Math.floor(Math.random() * 8)]
    swatches: config.colorOptions
    onSelect: (color, inst)->
      if not colorselectcounter
        colorselectcounter+=1
        return
      state.color= color.hex
      now.setServerState('color', state.color)
      if colorselectcounter > 1
        insertMessage('Hey', 'Nice color!')
      colorselectcounter+=1
      # console.log 'setting color'
      # $.colorpicker._hideColorpicker()


  inputEl.keypress (e) ->
    # console.log e.which
    if not state.isTopLayerInteractive
      return false
    if e.which in [0, 13, 32, 9, 8] # 40, 39, 38  were here, but that seems to be single quote?
      return false
    else
      c = String.fromCharCode e.which
      state.selectedCell.write(c)

      userTotalRites=parseInt($userTotalRites.text())
      $userTotalRites.text(userTotalRites+1)
      if not config.isAuth() and (userTotalRites is 4 or userTotalRites is 25)
        insertMessage('Register!!1', "With an account, all the stuff you're writing gets archived to a personal world, where nobody can mess with it", 'alert-info')
      moveCursor(state.writeDirection)
      return

  inputEl.keydown (e) ->
    if not state.isTopLayerInteractive
      return false

    # if not (state.belowInputRateLimit)
    #   return false
    # state.belowInputRateLimit = false
    # $.doTimeout 'keydownlimit', config.inputRateLimit(), ->
    #   state.belowInputRateLimit =true
    #   return false

    switch e.which
      when 9 #tab
        e.preventDefault()
        return false
      when 38
        moveCursor('up', null, true, true)
      when 40
        moveCursor('down', null, true, true)
      when 39
        moveCursor('right', null, true, true)
      when 37
        moveCursor('left', null, true, true)
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
        if km<=config.maxJumpDistance()
          map.panTo(latlng)
          state.geoPos= latlng
        else if config.isAuth()
          state.isLocal = false
          map.panTo(latlng)
          state.geoPos= latlng
          now.isLocal= false
        else
          insertMessage('Too Far!', "Sorry, you can't jump that far.  Register to go wherever you want.")
        $('#locationSearch').modal('hide')
        centerCursor()
    return false

  $("a#makeLink").click ->
    if not config.isAuth()
      insertMessage('Register', 'If you want to add links', "alert-error")
      return false
    else
      return true

  $("#linkModal").submit ->
    $('#linkModal').modal('hide')
    url= $("#linkurl").val()
    state.linkurl=url
    return false

  $(".modal").on 'shown', ->
    $(this).find('input')[0]?.focus()
 
  $(".modal").on 'hidden', ->
    inputEl.focus()

  $(".trigger").live 'click', ->
    action= $(this).data('action')
    type= $(this).data('type')
    payload= $(this).data('payload')
    text = $(this).text()
    # console.log text
    $(this).parent().parent().find('.active').removeClass('active')
    $(this).parent().addClass('active')
    # console.log 'trigger triggered'

    if type == 'geoLink'
      now.createGeoLink(state.selectedCell.key.slice(1), map.getZoom())
      #dang this won't work zoomed out, i don't have a selected cell...

    if action == 'hide' and type is 'notes'
      $('#notes').slideToggle()

    if action == 'set' #setServerState, more properly, like color
      state[type]=payload
      now.setServerState(type, payload)
    if action == 'setClientState' # unrelated to setClientStateFromServer, used for stuff like writedirection
      state[type] = payload

    if action == 'goto'
      goToCell(payload, map.getZoom())

    if action is 'show' and type is 'notes'
      $('#notes').slideToggle().find('.loading').load("/notes/#{payload}")
      $("#notes li").removeClass('active')
      $("#notes li.#{payload}").addClass('active')
      if payload is 'unread'
        $(this).find('i').removeClass('hasUnread')
      return false

    if action is 'get' and type is 'notes'
      $('#notes .loading').load("/notes/#{payload}")
      $("#notes li").removeClass('active')
      $("#notes li.#{payload}").addClass('active')
      return false
      
    if action is 'get' and type is 'info'
      now.getCellInfo()
      return false

    # if type=='layer'
      # do something
  
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


panIfAppropriate = (direction, force)->
  selectedPP= $(state.selectedEl).offset()
  panOnDist = 120
  if direction is 'left' or direction is 'right'
    panByDist = config.tileSize().x 
    panByDist = state.cellWidth() if force
  else
    panByDist = config.tileSize().y/2
    panByDist = state.cellHeight() if force
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
   
  welcome() if not config.isAuth()

  if not window.NOMAP then tileServeLayer = new L.TileLayer(config.tileServeUrl(), {maxZoom: config.maxZoom()}) else  tileServeLayer = new L.TileLayer('', {maxZoom: config.maxZoom()})
  # state.baseLayer= tileServeLayer

  centerPoint= window.officialCities["New York City"]
  mapOptions =
    center: centerPoint
    attributionControl:false
    zoom: config.defZoom()
    scrollWheelZoom: config.scrollWheelZoom()
    minZoom: config.minZoom()
    maxZoom: config.maxZoom()-window.MapBoxBadZoomOffset
  window.map= new L.Map('map', mapOptions).addLayer(tileServeLayer)
  
  map.preZoom= (zoomDelta,cb) ->
    current= map.getZoom()
    if zoomDelta > 0 #zooming out
      if current <= config.minLayerZoom() and state.isTopLayerInteractive
        layerUtils.remove(state.topLayerStamp)
        $.doTimeout 200, ->
          layerUtils.addCanvas()
          return false
        insertMessage('No Writing', " You've zoomed out too far to write. Zoom back in to write again.")

    else if zoomDelta < 0  #zooming in
      if current >= config.minLayerZoom()-1 and not state.isTopLayerInteractive
        layerUtils.remove(state.topLayerStamp)
        layerUtils.addDom()
        #
        # now.setBounds getLayer(state.topLayerStamp).getTilePointAbsoluteBounds()
    
    if current==config.minZoom()+1 and  zoomDelta > 0
      insertMessage('Zoomed Out', "That's as far as you can zoom out right now.")
      return false

    cb()
    return

  state.geoLinked = window.location.hash.slice(1)
  initializeGeo()

  now.ready ->
    doNowInit(now)
    # now.core.socketio.on 'reconnect', -> #   console.log 'reconnected!'
    return # end now.ready

  return true # end doc.ready

doNowInit= (now)->
    # now.mapGoTo= (latlng) ->
    #   console.log 'hi1', latlng
    #   l = new L.LatLng(latlng.x, latlng.y)
    #   map.setView(l)

    # now.goToGeoLink(state.geoLinked) if state.geoLinked

    domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
    
    state.topLayerStamp = L.Util.stamp domTiles
    now.isLocal= state.isLocal

    now.numRC= state.numRows()
    now.setGroup(initialWorldId)
    now.currentWorldId= initialWorldId
    now.personalWorldId= personalWorldId #may be blank

    map.addLayer(domTiles)
    
    $.doTimeout 2000, ->
      if not state.selectedCell
        return true
      else
        $.doTimeout 4000, ->
          now.getCursors()
          return false
        return false

    setTileStyle() #set initial

    map.on 'zoomend', ->
      setTileStyle()
      now.numRC= state.numRows()
      $('.leaflet-tile a').tooltip({placement:'top'})

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

    now.setClientStateFromServer (s)->
      state.userPowers = s.powers
      # console.log 'setcl from serv', s
      if s.color # s is session
        state.color= s.color
        $('#colorPicker').colorpicker("option", "color", s.color)
      else
        state.color=config.colorOptions[ Math.floor(Math.random() * 8)]
        $('#colorPicker').colorpicker("option", "color", state.color)
        now.setServerState('color', state.color)
 
    centerCursor()

    now.goTo =(latlng) ->
        map.panTo(latlng)
        return
      
    now.updateCursors = (updatedCursor) ->
      # console.log updatedCursor
      #todo, what if they go out of bounds and come back? something here is buggy
      if state.cursors[updatedCursor.cid]
        cursor=state.cursors[updatedCursor.cid]
        selectedCell = Cell.get(cursor.x, cursor.y)
        # console.log selectedCell
        if selectedCell
          selectedCell.cursor(false)
      state.cursors[updatedCursor.cid]= updatedCursor
      cursor= updatedCursor
      if cursor.x and cursor.y
        selectedCell = Cell.get(cursor.x, cursor.y)
        if selectedCell
          selectedCell.cursor(cursor.color)
      else
        delete state.cursors[cursor.cid] # on disconnect, remove
      return

    $("#getNearby").click ->
      now.getCloseUsers (closeUsers)->
        # console.log closeUsers
        $("#nearby").empty()
        if closeUsers.length is 0
          $("ul#nearby").append -> $ "<li> <a>Sorry, no one is nearby. </a> <small> Or they're too zoomed out to count.</small></li>"
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
            arrow= $("<li><a class='trigger' data-action='goto' data-payload='#{user.cursor.x-1}x#{user.cursor.y-1}'><i class='icon-arrow-left' style='-moz-transform: rotate(#{user.degrees}deg);-webkit-transform: rotate(#{user.degrees}deg);'></i> #{user.login}</a></li>")
      return
    
    now.drawRite = (commandType, rite, cellPoint, cellProps) ->
      # console.log(commandType, rite, cellPoint)
      c=Cell.get(cellPoint.x, cellPoint.y)
      c[commandType](rite, cellProps)

    now.insertMessage = (heading, message, cssclass, timing=6) ->
      insertMessage(heading, message, cssclass, timing)
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
# possibly fixed, check with two screens

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
    if @props.linkurl
      $(@span).addClass('link')
      @span.innerHTML= "<a href='#{@props.linkurl}' TARGET='_blank' rel='tooltip' title='#{@props.linkurl}'>#{@contents}</a>"

    @span.id= @key
    $(@span).addClass('cell')

    if not @props.color
      @props.color = 'c0'
    # $(@span).addClass(@props.color)
    @span.style.color="##{@props.color}"
    if @props.echoes
      $(@span).addClass("e#{@props.echoes}")
    
    @watch "contents", (id, oldval, newval) ->
      @span.innerHTML=newval
      return newval

    $span = $(@span)
    span=@span
    @props.watch "echoes", (id, oldval, newval) ->
      $span.removeClass('e'+oldval)
      $span.addClass('e'+newval)
      return newval

    @props.watch "color", (id, oldval, newval) ->
      span.style.color="##{newval}"
      return newval

  write: (c) ->
    cellPoint = cellKeyToXY @key
    if state.linkurl
      contents={contents:c, linkurl: state.linkurl}
      now.writeCell(cellPoint, contents)
      state.linkurl=false
      now.setServerState('linked', true)
    else
      now.writeCell(cellPoint, c)
    return
    # TODO this is so simple, but really we should be handling this client side. lag will be frustrating.

  cursor: (color) ->
      if color
        @span.style.backgroundColor='#'+color
        @span.className+=' otherSelected '
      else
        @span.style.backgroundColor=''
        $(@span).removeClass('otherSelected')
      return

  # COMMAND PATTERN
  normalRite: (rite, cellProps) ->
    @contents = rite.contents
    @props.color= rite.props.color
    if rite.props.linkurl
      @props.linkurl=rite.props.linkurl
      $(@span).addClass('link')
      @span.innerHTML= "<a href='#{@props.linkurl}' TARGET='_blank' rel='tooltip' title='#{@props.linkurl}'>#{@contents}</a>"

  echo: (rite, cellProps) ->
    @props.echoes = cellProps.echoes
    @animateText(1)
    @props.color= cellProps.color

  overrite: (rite, cellProps) ->
    @animateTextRemove()
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
  
  animateTextInsert: (c, animateWith, color=state.color, welcome=false) ->
    clone=  document.createElement('SPAN') #$(@span).clone().removeClass('selected')
    clone.className='cell ' + color
    clone.innerHTML=c
    span=@span
    if not animateWith
        animateWith=Math.floor(Math.random() * 3)+1
    $(clone).css('position', 'absolute').insertBefore('body').addClass('ai'+animateWith)
    offset= $(@span).offset()
    $(clone).css({'opacity': '1 !important', 'font-size': '1em'})
    $(clone).css({'position':'absolute', left: offset.left, top: offset.top})
    if not welcome
      $(clone).doTimeout 200, ->
        span.innerHTML = c
        span.className+=" #{color} "
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
      $(this).show().css({'fontSize':'+=90' , 'marginTop': "-=45", 'marginLeft': "-=45"})
      $(this).dequeue()
    $(clone).doTimeout 400, ->
      $(this).css({'fontSize':'-=90', 'marginTop': 0, 'marginLeft': 0})
      this.doTimeout 400, ->
        $(span).show()
        $(clone).remove()
      return false

  animateTextRemove: (animateWith) ->
    if not animateWith
      animateWith= Math.floor(Math.random() * 3)+1
    span= @span #the original
    clone=  $(@span).clone()
    @span.innerHTML= config.defaultChar()
    # @span.className= 'cell'
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


layerUtils=
  remove: (stamp) ->
    layer= map._layers[stamp]
    map.removeLayer(layer)
    return
  addCanvas: ->
    canvasTiles = new L.WCanvas({tileSize:{x:192, y:256}})
    map.addLayer canvasTiles
    state.isTopLayerInteractive= false
    state.topLayerStamp = L.Util.stamp(canvasTiles)
    state.selectedCell = null
    state.lastClickCell = null
    now.setBounds false
    return
  addDom: ->
    map.options.zoomAnimation = false
    domTiles = new L.DomTileLayer {tileSize: config.tileSize()}
    map.addLayer(domTiles)
    state.topLayerStamp = L.Util.stamp(domTiles)
    state.isTopLayerInteractive= true
    now.setBounds domTiles.getTilePointAbsoluteBounds()
    inputEl.focus()
    centerCursor()
    $.doTimeout 1000, ->
      map.options.zoomAnimation =true
      return false
    return

welcome = ->
  welcome_message=[]
  welcome_message.push c for c in "Hey. Try typing on the map./It'll be fun. I swear. // You can move around with the mouse and arrow keys. "
  welcome_cells=[]
  $.doTimeout 10000, ->
    $('.cS0').live 'click', ->
      $.doTimeout 'welcome'
      $('.cS0').addClass('ar1').doTimeout 200, -> @remove()
    map.on 'movestart', ->
      $('.cS0').addClass('ar1').doTimeout 200, -> @remove()
      $.doTimeout 'welcome'
    inputEl.keypress (e) ->
      $('.cS0').addClass('ar1').doTimeout 200, -> @remove()
      $.doTimeout 'welcome'
    layer=getLayer(state.topLayerStamp)
    if not layer then return true
    target=layer.getCenterTile()
    target.x-=15
    target.y-=10
    initial_x = target.x
    key = "c#{target.x}x#{target.y}"
    targetCell=Cell.all()[key]
    if not targetCell then return true
    $.doTimeout 'welcome', 120, ->
      l = welcome_message.shift()
      if l == '/'
        target.y+=1
        target.x = initial_x
      else
        target.x+=1
        key = "c#{target.x}x#{target.y}"
        targetCell=Cell.all()[key]
        targetCell.animateTextInsert(l, 99, 'cS0', true)
        welcome_cells.push targetCell
      if welcome_message.length
        return true
      else
        $.doTimeout 8000, ->
          $('.cS0').addClass('ar1').doTimeout 200, -> @remove()
          return false
        return false
    return false

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

window.goToCell= (key, zoom=false) ->
  if not zoom
    [z, x, y] = key.split('x')
  else
    [x, y] = key.split('x')
    z =zoom
  zoomDiff=config.maxZoom()-z
  numRC =Math.pow(2, zoomDiff)
  cWidth = config.tileSize().x/numRC
  cHeight = config.tileSize().y/numRC
  pixelX = x*cWidth
  pixelY = y*cHeight
  # console.log pixelX, pixelY
  latlng=map.unproject({x:pixelX, y:pixelY}, z)
  # console.log latlng
  map.setView(latlng, z)
  $.doTimeout 200, ->
    cell = Cell.get(x,y)
    if not cell then return true
    else
      setCursor(cell)
      return false
  return latlng


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
