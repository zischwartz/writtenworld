(function() {
  var CellSchema, ObjectId, RiteModel, RiteSchema, Schema, WorldSchema, mongoose;

  mongoose = require('mongoose');

  Schema = mongoose.Schema;

  ObjectId = Schema.ObjectId;

  WorldSchema = new Schema({
    owner: ObjectId,
    name: {
      type: String,
      unique: true
    },
    created: {
      type: Date,
      "default": Date.now
    },
    personal: {
      type: Boolean,
      "default": true
    }
  });

  exports.WorldModel = mongoose.model('World', WorldSchema);

  RiteSchema = new Schema({
    contents: {
      type: String,
      "default": ' '
    },
    date: {
      type: Date,
      "default": Date.now
    },
    owner: ObjectId,
    echos: {
      type: Number,
      "default": 0
    },
    color: {
      type: String,
      "default": ' '
    }
  });

  RiteModel = mongoose.model('Rite', RiteSchema);

  CellSchema = new Schema({
    world: ObjectId,
    x: {
      type: Number,
      required: true,
      min: 0
    },
    y: {
      type: Number,
      required: true,
      min: 0
    },
    contents: {
      type: String,
      "default": ' '
    },
    history: [RiteSchema]
  });

  CellSchema.index({
    world: 1,
    x: 1,
    y: 1
  }, {
    unique: true
  });

  exports.CellModel = mongoose.model('Cell', CellSchema);

  exports.writeCellToDb = function(cellPoint, contents, worldId) {
    return exports.CellModel.findOne({
      world: worldId,
      x: cellPoint.x,
      y: cellPoint.y
    }, function(err, cell) {
      var rite;
      if (!cell) {
        cell = new exports.CellModel({
          x: cellPoint.x,
          y: cellPoint.y,
          contents: contents,
          world: worldId
        });
        console.log('created  cell!!', cell.x, cell.y);
        rite = new RiteModel({
          contents: contents
        });
        cell.history.push(rite);
        return cell.save(function(err) {
          if (err) return console.log(err);
        });
      } else {
        cell.contents = contents;
        rite = new RiteModel({
          contents: contents
        });
        cell.history.push(rite);
        cell.save(function(err) {
          if (err) return console.log(err);
        });
        return console.log('updated cell', cell.x, cell.y);
      }
    });
  };

}).call(this);
