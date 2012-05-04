


console.log 'hellooo other worlds'
nowjs = require 'now'
models= require './models'

fs = require('fs')
trie=require './lib/trie.js'

rootVert = new trie.Vertex('')
word_trie = new trie.Trie(rootVert)

root = __dirname + '/lib/'

fs.readFile root+"TWL06.txt", (err,data) ->
  words= data.toString().split('\n')
  for w in words
    w= w.toLowerCase()
    word_trie.addWord(rootVert, w)
  return

module.exports = (SessionModel) ->

  doStuff = ->
     console.log 'doing stuff'
     val = 'hellox'
     out=word_trie.retrieve(val)
     console.log out
     return

  words =
    begin: (nowUser) ->
      # console.log nowUser
      if not nowUser.session?.letters
        hand = sevenLetters()
        nowUser.session.letters = hand
        nowUser.session.save()
      else
        hand = nowUser.session.letters
      nowjs.getClient nowUser.clientId, ->
        # console.log this.now
        formatted_hand=""
        for l in hand
          formatted_hand+="<div class='btn'>#{l.toUpperCase()} </div>"
        this.now.insertMessage 'Welcome', "Here are your letters #{formatted_hand}", 'major alert-info' , 1000

    write: (cellPoint, contents, nowUser, callback) ->
     console.log 'yeah rite!'
     c = contents.toLowerCase()
     if c in nowUser.session.letters
       console.log 'you have that letter'
       models.getContigs cellPoint, nowUser.currentWorldId, (contigs) ->
          console.log 'contigs', contigs

       riter = nowUser.soid
       rite = new models.Rite({contents: contents, owner:riter, props:{}})
       models.Cell .findOne({world: nowUser.currentWorldId, x:cellPoint.x, y: cellPoint.y}) .populate('current')
       .run (err, cell) ->
          # check contig, prewrite... unless its a valid one letter word?
          console.log err if err
          cell = new models.Cell {x:cellPoint.x, y:cellPoint.y, world: nowUser.currentWorldId} if not cell
          cell.history.push(rite)
          rite.save (err) ->
            cell.current= rite._id
            cell.save()
            callback('normalRite', rite, cellPoint)

  module.words = words

  return module


all_letters = ['a','b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y','z']
# Helpers
#
sevenLetters = ->
  letters= []
  for i in [1..7]
    r= Math.floor(Math.random() * 25) + 1
    letters.push(all_letters[r])
  return letters
