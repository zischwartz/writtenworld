(function() {
  var Cell, cellKeyToXY, filter, getNodeIndex, initializeInterface, moveCursor, pan, panIfAppropriate, setTileStyle,
    __slice = Array.prototype.slice;

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
    },
    belowInputRateLimit: true
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
    if (cell.props) if (cell.props.decayed) cell.animateTextRemove(1);
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
    if (!targetCell) {
      return false;
    } else {
      panIfAppropriate(direction);
      setSelected(targetCell);
    }
    return true;
  };

  window.centerCursor = function() {
    return $.doTimeout(400, function() {
      var key, target, targetCell;
      target = window.domTiles.getCenterTile();
      key = "c" + target.x + "x" + target.y;
      targetCell = Cell.all()[key];
      if (!targetCell) {
        return true;
      } else {
        setSelected(targetCell);
        return false;
      }
      return true;
    });
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
      var c, cellPoint, userTotalRites, _ref;
      dbg(e.which, 'pressed');
      if ((_ref = e.which) === 0 || _ref === 13 || _ref === 32 || _ref === 9 || _ref === 38 || _ref === 40 || _ref === 39 || _ref === 8) {
        return false;
      } else {
        c = String.fromCharCode(e.which);
        state.selectedCell.write(c);
        userTotalRites = parseInt($("#userTotalRites").text());
        $("#userTotalRites").text(userTotalRites + 1);
        cellPoint = cellKeyToXY(state.selectedCell.key);
        return moveCursor(state.writeDirection);
      }
    });
    inputEl.keydown(function(e) {
      dbg(e.which, ' keydownd');
      if (!state.belowInputRateLimit) return false;
      state.belowInputRateLimit = false;
      $.doTimeout('keydownlimit', config.inputRateLimit(), function() {
        state.belowInputRateLimit = true;
        return false;
      });
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          return moveCursor('up');
        case 40:
          return moveCursor('down');
        case 39:
          return moveCursor('right');
        case 37:
          return moveCursor('left');
        case 8:
          moveCursor('left');
          state.selectedCell.clear();
          return setSelected(state.selectedCell);
        case 13:
          return moveCursor('down', state.lastClickCell);
        case 32:
          state.selectedCell.clear();
          return moveCursor(state.writeDirection);
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
          $('#locationSearch').modal('hide');
          return centerCursor();
        }
      });
      return false;
    });
    $(".modal").on('shown', function() {
      var _ref;
      return (_ref = $(this).find('input')[0]) != null ? _ref.focus() : void 0;
    });
    $(".modal").on('hidden', function() {
      return inputEl.focus();
    });
    return $(".trigger").live('click', function() {
      var action, c, payload, type;
      action = $(this).data('action');
      type = $(this).data('type');
      payload = $(this).data('payload');
      if (action === 'set') {
        state[type] = payload;
        now.setUserOption(type, payload);
      }
      if (action === 'setClientState') state[type] = payload;
      if (type === 'color') {
        $("#color").addClass(payload);
        inputEl.focus();
      }
      if (type === 'writeDirection') {
        c = this.innerHTML;
        $('.direction-dropdown')[0].innerHTML = c;
        $('.direction-dropdown i').addClass('icon-white');
        inputEl.focus();
      }
      return true;
    });
  };

  panIfAppropriate = function(direction) {
    var panByDist, panOnDist, selectedPP;
    selectedPP = $(state.selectedEl).offset();
    dbg('selectedPP', selectedPP);
    panOnDist = 200;
    if (direction === 'left' || direction === 'right') {
      panByDist = state.cellWidth();
    } else {
      panByDist = state.cellHeight();
    }
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
    if (!USEMAP) {
      window.map = new L.Map('map', {
        center: centerPoint,
        zoom: 17,
        scrollWheelZoom: false,
        minZoom: config.minZoom(),
        maxZoom: config.maxZoom()
      });
    } else {
      window.map = new L.Map('map', {
        center: centerPoint,
        zoom: 17,
        scrollWheelZoom: false,
        minZoom: config.minZoom(),
        maxZoom: config.maxZoom()
      }).addLayer(tileServeLayer);
    }
    initializeGeo();
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
      map.on('moveend', function(e) {
        return now.setBounds(domTiles.getTilePointAbsoluteBounds());
      });
      map.on('zoomend', function(e) {
        return now.setBounds(domTiles.getTilePointAbsoluteBounds());
      });
      now.setClientStateFromServer(function(s) {
        if (s.color) {
          return state.color = s.color;
        } else {
          state.color = 'c0';
          return now.setUserOption('color', 'c0');
        }
      });
      centerCursor();
      now.drawCursors = function(user) {
        var otherSelected;
        $(".u" + user.cid).removeClass("otherSelected u" + user.cid + " c" + user.color);
        if (user.selected.x) {
          otherSelected = Cell.get(user.selected.x, user.selected.y);
          if (otherSelected) {
            return $(otherSelected.span).addClass("u" + user.cid + " c" + user.color + " otherSelected");
          }
        }
      };
      now.drawEdits = function(edits) {
        var c, edit, id, _results;
        _results = [];
        for (id in edits) {
          edit = edits[id];
          c = Cell.get(edit.cellPoint.x, edit.cellPoint.y);
          if (c) {
            _results.push(c.update(edit.content, edit.props));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      };
      now.insertMessage = function(heading, message, cssclass) {
        return insertMessage(heading, message, cssclass);
      };
      return true;
    });
    return true;
  });

  window.insertMessage = function(heading, message, cssclass, timing) {
    var html;
    if (cssclass == null) cssclass = "";
    if (timing == null) timing = 6;
    html = "<div class='alert alert-block fade  " + cssclass + " '><a class='close' data-dismiss='alert'>×</a><h4 class='alert-heading'>" + heading + "</h4>" + message + "</div>";
    if (timing > 0) {
      return $("#messages").append(html).children().doTimeout(100, 'addClass', 'in').doTimeout(timing * 1000, function() {
        return $(this).removeClass('in').doTimeout(300, function() {
          return $(this).alert('close').remove();
        });
      });
    } else {
      return $("#messages").append(html).children().doTimeout(100, 'addClass', 'in');
    }
  };

  window.clearMessages = function() {
    $("#messages").children().removeClass('in').doTimeout(300, function() {
      return $(this).alert('close').remove();
    });
    return true;
  };

  $().alert();

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
      if (!this.props.color) this.props.color = 'c0';
      this.span.className = 'cell ' + this.props.color;
      if (this.props.echoes) this.span.className += " e" + this.props.echoes;
    }

    Cell.prototype.write = function(c) {
      var cellPoint;
      dbg('Cell write  called');
      if (this.contents) this.animateTextRemove(1);
      this.contents = c;
      this.span.className = 'cell ' + state.color;
      this.animateTextInsert(2, c);
      cellPoint = cellKeyToXY(this.key);
      return now.writeCell(cellPoint, c);
    };

    Cell.prototype.update = function(contents, props) {
      dbg('Cell update called');
      this.contents = contents;
      this.span.innerHTML = contents;
      return this.span.className = 'cell ' + props.color;
    };

    Cell.prototype.kill = function() {
      dbg('killing a cell');
      this.span = null;
      return delete all[this.key];
    };

    Cell.prototype.clear = function() {
      this.span.innerHTML = config.defaultChar();
      this.write(config.defaultChar());
      return this.span.className = 'cell';
    };

    Cell.prototype.animateTextInsert = function(animateWith, c) {
      var clone, offset, span;
      if (animateWith == null) animateWith = 0;
      clone = document.createElement('SPAN');
      clone.className = 'cell ' + state.color;
      clone.innerHTML = c;
      span = this.span;
      $(clone).css('position', 'absolute').insertBefore('body').addClass('a' + animateWith);
      offset = $(this.span).offset();
      dbg('clone', clone);
      $(clone).css({
        'opacity': '1 !important',
        'font-size': '1em'
      });
      $(clone).css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      });
      return $(clone).doTimeout(400, function() {
        span.innerHTML = c;
        $(clone).remove();
        return false;
      });
    };

    Cell.prototype.animateTextRemove = function(animateWith) {
      var clone, offset, span;
      if (animateWith == null) animateWith = 0;
      span = this.span;
      clone = $(this.span).clone();
      this.span.innerHTML = config.defaultChar();
      offset = $(this.span).position();
      $(this.span).after(clone);
      $(clone).removeClass('selected');
      $(clone).css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      }).hide();
      $(clone).queue(function() {
        $(this).show();
        dbg('this', this);
        if (animateWith) $(this).addClass('a' + animateWith);
        return $(this).dequeue();
      });
      return $(clone).doTimeout(800, function() {
        $(clone).remove();
        return false;
      });
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
