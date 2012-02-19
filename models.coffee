mongoose= require 'mongoose'

# NEED TO WRITE EXPORTS and integrate with app.coffee

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

#yeah hardwiring!

WorldSchema = new Schema
  owner: ObjectId
  name: {type: String, unique: true,}
  created: { type: Date, default: Date.now }
  personal: {type: Boolean, default: true}

exports.WorldModel = mongoose.model('World', WorldSchema)

RiteSchema = new Schema
  contents: {type: String, default: ' '}
  date: { type: Date, default: Date.now }
  owner: ObjectId
  echos: {type: Number, default: 0}
  color: {type: String, default: ' '}

RiteModel = mongoose.model('Rite', RiteSchema)

CellSchema = new Schema
  world: ObjectId
  x: {type: Number, required: true, min: 0}
  y: {type: Number, required: true, min: 0}
  contents: {type: String, default: ' '} #remove this in favor of history[history.length]
  history: [RiteSchema] # a collection of Rites

CellSchema.index {world:1, x:1, y:1}, {unique:true}

exports.CellModel = mongoose.model('Cell', CellSchema)

exports.writeCellToDb = (cellPoint, contents, worldId) ->
  exports.CellModel.findOne {world: worldId, x:cellPoint.x, y: cellPoint.y}, (err, cell) ->
    if not cell
      cell = new exports.CellModel {x:cellPoint.x, y:cellPoint.y, contents: contents, world:worldId}
      console.log 'created  cell!!', cell.x, cell.y
      rite = new RiteModel({contents: contents})
      cell.history.push(rite)
      cell.save (err) -> console.log err if err
    else
      cell.contents = contents
      rite = new RiteModel({contents: contents})
      cell.history.push(rite)
      cell.save (err) -> console.log err if err
      console.log 'updated cell', cell.x, cell.y
