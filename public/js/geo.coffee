
window.initializeGeo = ()->
  if (navigator.geolocation)
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed)

      $.doTimeout 500,  ->
        if (not state.geoPos) or (state.geoAccuracy ==-1)
          window.insertMessage "Click Allow", "If your browser asks to track your location, please click <b>allow</b>." , 'alert-error'
        return false
  
      watchID = navigator.geolocation.watchPosition (position)->
        # console.log 'recieved new loc! ', position
        if position.coords.accuracy < 500
          # console.log 'more accurate loc found'
          timeSinceLoad= new Date().getTime()-window.pageStartLoad
          if not state.geoPos and (timeSinceLoad>1200)
            window.insertMessage "We found you", "It took a second, but we've found your location more accurately. Moving you there shortly." , 'alert-info'
            state.selectedCell = false
            $.doTimeout 1000, geoHasPosition(position)
          else
            # console.log 'moving it without telling you'
            state.selectedCell = false
            geoHasPosition(position)
          navigator.geolocation.clearWatch(watchID)

  if not state.geoPos
    $.getScript 'http://j.maxmind.com/app/geoip.js', (data, textStatus) ->
      # console.log 'maxmind'
      # console.log {coords:{latitude: geoip_latitude(), longitude: geoip_longitude(), accuracy:-1}}
      geoHasPosition {coords:{latitude: geoip_latitude(), longitude: geoip_longitude(), accuracy:-1}} if not state.geoPos
      return true


geoFailed = (error) ->
  # console.log 'geo position failed'
  return true

geoSucceeded = (position) ->
  # console.log 'position from geoSucceed', position
  state.selectedCell = false
  geoHasPosition position if not state.geoPos
  true

# chicago = new L.LatLng(41.878114,-87.629798) # for testing
# nj = new L.LatLng(40.058324,-74.405661) # for testing
la = new L.LatLng(34.052234,-118.243685) # for testing
nyc= new L.LatLng(40.73037270272987, -73.99361729621887)

geoHasPosition = (position) ->
  # console.log 'has pos', position 
  linkPos=config.initialPos()
  if linkPos
    state.isLocal=false
    p=goToCell(linkPos)
    state.geoPos = p
    state.initialGeoPos = new L.LatLng(p.lat, p.lng)
    return true

  #normal (not from a geolink)
  inOfficialCity = false
  closest= ''
  distanceToClosest = 10000000000000000000000000000000

  p = new L.LatLng(position.coords.latitude,position.coords.longitude)
  
  # p =la  #FOR DEBUG 

  state.geoPos = p
  state.geoAccuracy = position.coords.accuracy
  if window.VARYLATLNG and position.coords.accuracy > 2000 or position.coords.accuracy is -1
    p = varyLatLng(p)
  state.geoPos = p
  state.initialGeoPos = new L.LatLng(p.lat, p.lng)
  for own key, val of officialCities
    distance = p.distanceTo(val)
    if distance < config.maxDistanceFromOfficial()
      inOfficialCity= true
    if distance < distanceToClosest
      distanceToClosest = distance
      closest= key

  if inOfficialCity
    map.setView(p, config.defZoom() )
    window.centerCursor()
    state.isLocal=true

  else
    # console.log 'not official city YO'
    # if window.VARYLATLNG
    #   map.setView(varyLatLng(officialCities[closest]), config.defZoom() )
    # else
    #   map.setView(officialCities[closest], config.defZoom() )
    # msgbody="We're in beta, so we're concentrating on a few cities for now. We took you to <b>#{closest}</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty. <br><br><a href='#' class='goToActualPos btn btn-primary' data-dismiss='alert'>Go to your location</a> <a href='#' class='btn' data-dismiss='alert'>Stay</a>"
    map.setView(p, config.defZoom() )
    msgbody="We're in beta, so your location may be kinda empty. New York City is pretty crazy if you'd like to check it out: <br><br><a href='#' class='goToNYC btn btn-primary' data-dismiss='alert'>Go to NYC</a> <a href='#' class='btn' data-dismiss='alert'>Stay</a>"
    # window.clearMessages()
    # window.insertMessage "&quotHey, That's Not Where I Am!&quot", msgbody, 'alert-info', 45 # was major
    window.insertMessage "&quotWhere is everyone? &quot", msgbody, 'alert-info', 95 # was major
    state.isLocal=false
  return true

$('.goToActualPos').live 'click', ->
  map.setView(state.geoPos, config.defZoom() )
  state.isLocal=true
  state.selectedCell = false
  window.centerCursor()
  true

$('.goToNYC').live 'click', ->
  map.setView(varyLatLng(nyc), config.defZoom() )
  state.isLocal=false
  state.selectedCell = false
  window.centerCursor()
  true

window.varyLatLng = (l) ->
  latOffset = Math.random()/100
  lngOffset = Math.random()/100
  if Math.random() > 0.5
    latOffset= 0-latOffset
  if Math.random() > 0.5
    lngOffset= 0-lngOffset
  p = new L.LatLng(l.lat+latOffset,l.lng+lngOffset)
  return p
