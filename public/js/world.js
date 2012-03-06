(function() {
  var Cell, Configuration, cellKeyToXY, centerCursor, filter, getNodeIndex, initializeInterface, moveCursor, pan, panIfAppropriate, setTileStyle,
    __slice = Array.prototype.slice;

  window.DEBUG = false;

  window.Configuration = Configuration = (function() {

    function Configuration(spec) {
      if (spec == null) spec = {};
      this.tileSize = function() {
        var _ref;
        return (_ref = spec.tileSize) != null ? _ref : {
          x: 192,
          y: 256
        };
      };
      this.maxZoom = function() {
        var _ref;
        return (_ref = spec.maxZoom) != null ? _ref : 20;
      };
      this.defaultChar = function() {
        var _ref;
        return (_ref = spec.defaultChar) != null ? _ref : " ";
      };
    }

    return Configuration;

  })();

  window.config = new Configuration;

  window.state = {
    selectedCell: null,
    lastClickCell: null,
    color: null,
    writeDirection: 'right',
    zoomDiff: function() {
      return config.maxZoom() - map.getZoom();
    },
    numRows: function() {
      var numRows;
      return numRows = Math.pow(2, state.zoomDiff());
    },
    numCols: function() {
      var numCols;
      return numCols = Math.pow(2, state.zoomDiff());
    },
    cellWidth: function() {
      return config.tileSize().x / state.numCols();
    },
    cellHeight: function() {
      return config.tileSize().y / state.numRows();
    }
  };

  setTileStyle = function() {
    var fontSize, height, rules, width;
    width = state.cellWidth();
    height = state.cellHeight();
    fontSize = height * 0.9;
    rules = [];
    rules.push("div.leaflet-tile span { width: " + width + "px; height: " + height + "px; font-size: " + fontSize + "px;}");
    return $("#dynamicStyles").text(rules.join("\n"));
  };

  window.setSelected = function(cell) {
    dbg('selecting', cell);
    if (state.selectedEl) $(state.selectedEl).removeClass('selected');
    state.selectedEl = cell.span;
    $(cell.span).addClass('selected');
    state.selectedCell = cell;
    now.setSelectedCell(cellKeyToXY(cell.key));
    return true;
  };

  moveCursor = function(direction, from) {
    var key, target, targetCell;
    if (from == null) from = state.selectedCell;
    dbg('move cursor');
    target = cellKeyToXY(from.key);
    switch (direction) {
      case 'up':
        target.y = target.y - 1;
        break;
      case 'down':
        target.y = target.y + 1;
        break;
      case 'left':
        target.x = target.x - 1;
        break;
      case 'right':
        target.x = target.x + 1;
    }
    key = "c" + target.x + "x" + target.y;
    targetCell = Cell.all()[key];
    if (!targetCell) return false;
    setSelected(targetCell);
    return true;
  };

  centerCursor = function() {
    var key, target, targetCell;
    target = window.domTiles.getCenterTile();
    key = "c" + target.x + "x" + target.y;
    targetCell = Cell.all()[key];
    if (!targetCell) return false;
    setSelected(targetCell);
    return true;
  };

  initializeInterface = function() {
    dbg('initializing interface');
    $("#map").click(function(e) {
      var cell;
      if ($(e.target).hasClass('cell')) {
        cell = Cell.all()[e.target.id];
        state.lastClickCell = cell;
        setSelected(cell);
        return inputEl.focus();
      } else {
        inputEl.focus();
        return false;
      }
    });
    window.inputEl = $("#input");
    inputEl.focus();
    map.on('zoomend', function() {
      return inputEl.focus();
    });
    inputEl.keypress(function(e) {
      var c, cellPoint, userTotalRites;
      if (e.which === 13) {
        moveCursor('down', state.lastClickCell);
        panIfAppropriate('down');
        return state.lastClickCell = state.selectedCell;
      } else {
        c = String.fromCharCode(e.which);
        dbg(c, 'PRESSED!!!!');
        state.selectedCell.write(c);
        userTotalRites = parseInt($("#userTotalRites").text());
        $("#userTotalRites").text(userTotalRites + 1);
        cellPoint = cellKeyToXY(state.selectedCell.key);
        now.writeCell(cellPoint, c);
        moveCursor(state.writeDirection);
        return panIfAppropriate(state.writeDirection);
      }
    });
    inputEl.keydown(function(e) {
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          moveCursor('up');
          return panIfAppropriate('up');
        case 40:
          moveCursor('down');
          return panIfAppropriate('down');
        case 39:
          moveCursor('right');
          return panIfAppropriate('right');
        case 37:
          moveCursor('left');
          return panIfAppropriate('left');
        case 8:
          moveCursor('left');
          panIfAppropriate('left');
          return state.selectedCell.write(' ');
      }
    });
    $("#locationSearch").submit(function() {
      var locationString;
      locationString = $("#locationSearchInput").val();
      $.ajax({
        url: "http://where.yahooapis.com/geocode?location=" + locationString + "&flags=JC&appid=a6mq7d30",
        success: function(data) {
          var latlng, result;
          result = data['ResultSet']['Results'][0];
          latlng = new L.LatLng(parseFloat(result.latitude), parseFloat(result.longitude));
          dbg('go to, ', latlng);
          map.panTo(latlng);
          return $('#locationSearch').modal('hide');
        }
      });
      return false;
    });
    $(".modal").on('shown', function() {
      var _ref;
      return (_ref = $(this).find('input')[0]) != null ? _ref.focus() : void 0;
    });
    return $(".modal").on('hidden', function() {
      return inputEl.focus();
    });
  };

  panIfAppropriate = function(direction) {
    var panByDist, panOnDist, selectedPP;
    selectedPP = $(state.selectedEl).offset();
    dbg('selectedPP', selectedPP);
    panOnDist = 200;
    panByDist = state.cellHeight();
    if (direction === 'up') if (selectedPP.top < panOnDist) pan(0, 0 - panByDist);
    if (direction === 'down') {
      if (selectedPP.top > document.body.clientHeight - panOnDist * 1.5) {
        pan(0, panByDist);
      }
    }
    if (direction === 'right') {
      if (selectedPP.left > document.body.clientWidth - panOnDist) {
        pan(panByDist, 0);
      }
    }
    if (direction === 'left') {
      if (selectedPP.left < panOnDist) return pan(0 - panByDist, 0);
    }
  };

  jQuery(function() {
    var centerPoint, tileServeLayer, tileServeUrl;
    tileServeUrl = 'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/999/256/{z}/{x}/{y}.png';
    tileServeLayer = new L.TileLayer(tileServeUrl, {
      maxZoom: config.maxZoom()
    });
    centerPoint = new L.LatLng(40.714269, -74.005972);
    if (DEBUG) {
      window.map = new L.Map('map', {
        center: centerPoint,
        zoom: 17,
        scrollWheelZoom: false
      });
    } else {
      window.map = new L.Map('map', {
        center: centerPoint,
        zoom: 17,
        scrollWheelZoom: false
      }).addLayer(tileServeLayer);
    }
    window.domTiles = new L.DomTileLayer({
      tileSize: config.tileSize()
    });
    now.ready(function() {
      now.setCurrentWorld(currentWorldId);
      map.addLayer(domTiles);
      setTileStyle();
      map.on('zoomend', function() {
        return setTileStyle();
      });
      initializeInterface();
      now.setBounds(domTiles.getTilePointAbsoluteBounds());
      now.setClientState(function(s) {
        if (s.color) return state.color = s.color;
      });
      $.doTimeout(500, function() {
        centerCursor();
        return false;
      });
      now.drawCursors = function(users) {
        var id, otherSelected, user, _results;
        $('.otherSelected').removeClass('otherSelected');
        _results = [];
        for (id in users) {
          user = users[id];
          if (user.selected.x) {
            otherSelected = Cell.get(user.selected.x, user.selected.y);
            _results.push($(otherSelected.span).addClass('otherSelected'));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      };
      now.drawEdits = function(edits) {
        var c, edit, id, _results;
        _results = [];
        for (id in edits) {
          edit = edits[id];
          c = Cell.get(edit.cellPoint.x, edit.cellPoint.y);
          _results.push(c.update(edit.content, edit.props));
        }
        return _results;
      };
      $(".trigger").live('click', function() {
        var action, payload, type;
        action = $(this).data('action');
        type = $(this).data('type');
        payload = $(this).data('payload');
        if (action === 'set') {
          console.log('setting');
          state[type] = payload;
          now.setUserOption(type, payload);
        }
        return true;
      });
      now.insertMessage = function(heading, message, cssclass) {
        var html;
        if (cssclass == null) cssclass = "";
        html = "<div class='alert fade  " + cssclass + " '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>" + heading + "</h4>" + message + "</div>";
        return $("#messages").append(html).children().doTimeout(100, 'addClass', 'in').doTimeout(5000, function() {
          return $(this).removeClass('in').doTimeout(300, function() {
            return $(this).alert('close').remove();
          });
        });
      };
      $().alert();
      map.on('moveend', function() {
        return now.setBounds(domTiles.getTilePointAbsoluteBounds());
      });
      return map.on('zoomend', function() {
        return now.setBounds(domTiles.getTilePointAbsoluteBounds());
      });
    });
    return true;
  });

  window.Cell = Cell = (function() {
    var all;

    all = {};

    Cell.all = function() {
      return all;
    };

    Cell.get = function(x, y) {
      return all["c" + x + "x" + y];
    };

    Cell.count = function() {
      var c, i;
      i = 0;
      for (c in all) {
        i++;
      }
      return i;
    };

    Cell.prototype.generateKey = function() {
      this.x = this.tile._tilePoint.x * Math.pow(2, state.zoomDiff()) + this.col;
      this.y = this.tile._tilePoint.y * Math.pow(2, state.zoomDiff()) + this.row;
      return "c" + this.x + "x" + this.y;
    };

    function Cell(row, col, tile, contents, props, events) {
      this.row = row;
      this.col = col;
      this.tile = tile;
      this.contents = contents != null ? contents : config.defaultChar();
      this.props = props != null ? props : {};
      this.events = events != null ? events : null;
      this.timestamp = null;
      this.key = this.generateKey();
      all[this.key] = this;
      this.span = document.createElement('span');
      this.span.innerHTML = this.contents;
      this.span.id = this.key;
      this.span.className = 'cell';
      if (this.props.color) this.span.className = 'cell ' + this.props.color;
      if (this.props.echoes) this.span.className += " e" + props.echoes;
    }

    Cell.prototype.write = function(c) {
      this.contents = c;
      this.span.innerHTML = c;
      if (state.color) return this.span.className = 'cell ' + state.color;
    };

    Cell.prototype.update = function(contents, props) {
      this.contents = contents;
      this.span.innerHTML = contents;
      this.span.className = 'cell';
      if (props.color) return this.span.className += ' ' + props.color;
    };

    Cell.prototype.kill = function() {
      dbg('killing a cell');
      this.span = null;
      return delete all[this.key];
    };

    Cell.prototype.clearSpan = function() {
      return this.span.innerHTML = config.defaultChar();
    };

    Cell.prototype.cloneSpan = function(animateWith) {
      if (animateWith == null) animateWith = 0;
      return $(this.span).clone().appendTo('.goodbye');
    };

    Cell.getOrCreate = function(row, col, tile, contents, props) {
      var cell, x, y;
      if (contents == null) contents = null;
      if (props == null) props = {};
      x = tile._tilePoint.x * Math.pow(2, state.zoomDiff()) + col;
      y = tile._tilePoint.y * Math.pow(2, state.zoomDiff()) + row;
      cell = Cell.get(x, y);
      if (cell) {
        return cell;
      } else {
        cell = new Cell(row, col, tile, contents, props);
        return cell;
      }
    };

    return Cell;

  })();

  pan = function(x, y) {
    var p;
    p = new L.Point(x, y);
    map.panBy(p);
    return map;
  };

  cellKeyToXY = function(key) {
    var target, _ref;
    target = {};
    _ref = key.slice(1).split('x'), target.x = _ref[0], target.y = _ref[1];
    target.x = parseInt(target.x, 10);
    target.y = parseInt(target.y, 10);
    return target;
  };

  window.cellXYToKey = function(target) {
    return "c" + target.x + "x" + target.y;
  };

  filter = function(list, func) {
    var x, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = list.length; _i < _len; _i++) {
      x = list[_i];
      if (func(x)) _results.push(x);
    }
    return _results;
  };

  Array.prototype.remove = function(e) {
    var t, _ref;
    if ((t = this.indexOf(e)) > -1) {
      return ([].splice.apply(this, [t, t - t + 1].concat(_ref = [])), _ref);
    }
  };

  getNodeIndex = function(node) {
    return $(node).parent().children().index(node);
  };

  window.dbg = function() {
    var message, more;
    message = arguments[0], more = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    if (DEBUG) {
      console.log(message);
      return true;
    }
    if (DEBUG && more) {
      console.log(message, more);
      return true;
    }
    return true;
  };

}).call(this);
