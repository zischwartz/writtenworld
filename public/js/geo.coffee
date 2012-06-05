
window.initializeGeo = ()->
  if (navigator.geolocation)
      navigator.geolocation.getCurrentPosition(geoSucceeded, geoFailed) # navigator.geolocation.watchPosition geoWatch #possibly use this for mobile

  $.getScript 'http://j.maxmind.com/app/geoip.js', (data, textStatus) ->
    geoHasPosition {coords:{latitude: geoip_latitude(), longitude: geoip_longitude(), accuracy:-1}} if not state.geoPos
    return true


geoFailed = (error) ->
  return true

geoSucceeded = (position) ->
  geoHasPosition position if not state.geoPos
  true

# chicago = new L.LatLng(41.878114,-87.629798) # for testing
# nj = new L.LatLng(40.058324,-74.405661) # for testing
# la = new L.LatLng(34.052234,-118.243685) # for testing

geoHasPosition = (position) ->
  
  linkPos=config.initialPos()
  console.log linkPos
  if linkPos
    state.isLocal=false
    p = new L.LatLng(linkPos.x, linkPos.y)
    state.geoPos = p
    state.initialGeoPos = new L.LatLng(linkPos.x, linkPos.y)
    map.setView(p, config.defZoom() )
    return true

  #normal (not from a geolink)
  inOfficialCity = false
  closest= ''
  distanceToClosest = 10000000000000000000000000000000

  p = new L.LatLng(position.coords.latitude,position.coords.longitude)
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
    if window.VARYLATLNG
      map.setView(varyLatLng(officialCities[closest]), config.defZoom() )
    else
      map.setView(officialCities[closest], config.defZoom() )
    msgbody="We're in beta, so we're concentrating on a few cities for now. We took you to <b>#{closest}</b>.<br><br>Want a head start writing on your actual location? It may be kinda empty. <br><br><a href='#' class='goToActualPos btn btn-primary' data-dismiss='alert'>Go to your location</a> <a href='#' class='btn' data-dismiss='alert'>Stay</a>"
    window.clearMessages()
    window.insertMessage "&quotHey, That's Not Where I Am!&quot", msgbody, 'alert-info', 45 # was major
    state.isLocal=false
  return true

$('.goToActualPos').live 'click', ->
  map.setView(state.geoPos, config.defZoom() )
  state.isLocal=true
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
