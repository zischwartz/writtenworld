# objects relating to user powers and guides

powers=
  unregistered:
    description: 'not registered'
    colors: ['c0', 'c1', 'c2', 'c3']
  echo0:
    description: 'registered'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5']
  echo1:
    description: 'first echo'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6',]
  echo5:
    description: 'fifth echo'
    colors: ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7']


module.exports=
  getAvailableColors: (echoes) ->
    console.log 'echoes', echoes
    if echoes <= 0
      console.log 'ok'
      return powers.echo0.colors
    if echoes ==1
      return powers.echo1.colors
    if echoes >=5
      return powers.echo5.colors

  unregisteredColors: ->
    powers.unregistered.colors

