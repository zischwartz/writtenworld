// Generated by CoffeeScript 1.3.1
(function() {
  var Cell, cellKeyToXY, doNowInit, filter, getLayer, getNodeIndex, initializeInterface, layerUtils, moveCursor, pan, panIfAppropriate, setTileStyle, welcome,
    __slice = [].slice;

  window.state = {
    selectedCell: null,
    lastClickCell: null,
    color: null,
    geoPos: null,
    geoAccuracy: null,
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
    topLayerStamp: null,
    lastLayerStamp: null,
    isTopLayerInteractive: true,
    cursors: {},
    isLocal: true,
    belowArrowKeyRateLimit: true,
    linkurl: false
  };

  setTileStyle = function() {
    var fontSize, height, rules, width;
    width = state.cellWidth();
    height = state.cellHeight();
    fontSize = height * 0.9;
    rules = [];
    rules.push(".cell { width: " + width + "px; height: " + height + "px; font-size: " + fontSize + "px;}");
    return $("#dynamicStyles").text(rules.join("\n"));
  };

  window.setCursor = function(cell) {
    if (state.selectedEl) {
      $(state.selectedEl).removeClass('selected');
    }
    state.selectedEl = cell.span;
    $(cell.span).addClass('selected');
    state.selectedCell = cell;
    now.setCursor(cellKeyToXY(cell.key));
    return true;
  };

  moveCursor = function(direction, from, force, arrowKey) {
    var key, target, targetCell;
    if (from == null) {
      from = state.selectedCell;
    }
    if (force == null) {
      force = false;
    }
    if (arrowKey == null) {
      arrowKey = false;
    }
    if (arrowKey) {
      if (!state.belowArrowKeyRateLimit) {
        return false;
      }
      state.belowArrowKeyRateLimit = false;
      $.doTimeout('keydownlimit', config.inputRateLimit(), function() {
        state.belowArrowKeyRateLimit = true;
        return false;
      });
    }
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
      if (config.autoPan() || force) {
        panIfAppropriate(direction, force);
      }
      setCursor(targetCell);
      return targetCell;
    }
  };

  window.centerCursor = function() {
    $.doTimeout(400, function() {
      var key, layer, target, targetCell;
      if (state.selectedCell && $(".selected").length) {
        inputEl.focus();
        return false;
      }
      layer = getLayer(state.topLayerStamp);
      if (!layer) {
        return true;
      }
      target = layer.getCenterTile();
      key = "c" + target.x + "x" + target.y;
      targetCell = Cell.all()[key];
      if (!targetCell) {
        return true;
      } else {
        setCursor(targetCell);
        state.lastClickCell = targetCell;
        inputEl.focus();
        $('.leaflet-tile a').tooltip({
          placement: 'top'
        });
        return false;
      }
    });
    return true;
  };

  initializeInterface = function() {
    var $userTotalRites, colorselectcounter;
    $("#map").click(function(e) {
      var cell;
      if ($(e.target).hasClass('cell')) {
        cell = Cell.all()[e.target.id];
        state.lastClickCell = cell;
        setCursor(cell);
        inputEl.focus();
        return false;
      } else if (e.target.href) {
        return true;
      } else {
        inputEl.focus();
        return false;
      }
    });
    window.inputEl = $("#input");
    inputEl.focus();
    $('.navbar a').tooltip({
      placement: 'bottom'
    });
    map.on('zoomend', function() {
      inputEl.focus();
      return $("#loadingIndicator").fadeOut('fast');
    });
    $userTotalRites = $("#userTotalRites");
    colorselectcounter = 0;
    $("#colorPicker").colorpicker({
      realtime: false,
      color: config.colorOptions[Math.floor(Math.random() * 8)],
      swatches: config.colorOptions,
      onSelect: function(color, inst) {
        if (!colorselectcounter) {
          colorselectcounter += 1;
          return;
        }
        state.color = color.hex;
        now.setServerState('color', state.color);
        if (colorselectcounter > 1) {
          insertMessage('Hey', 'Nice color!');
        }
        return colorselectcounter += 1;
      }
    });
    inputEl.keypress(function(e) {
      var c, userTotalRites, _ref;
      if (!state.isTopLayerInteractive) {
        return false;
      }
      if ((_ref = e.which) === 0 || _ref === 13 || _ref === 32 || _ref === 9 || _ref === 8) {
        return false;
      } else {
        c = String.fromCharCode(e.which);
        state.selectedCell.write(c);
        userTotalRites = parseInt($userTotalRites.text());
        $userTotalRites.text(userTotalRites + 1);
        if (!config.isAuth() && (userTotalRites === 4 || userTotalRites === 25)) {
          insertMessage('Register!!1', "With an account, all the stuff you're writing gets archived to a personal world, where nobody can mess with it", 'alert-info');
        }
        moveCursor(state.writeDirection);
      }
    });
    inputEl.keydown(function(e) {
      var t;
      if (!state.isTopLayerInteractive) {
        return false;
      }
      switch (e.which) {
        case 9:
          e.preventDefault();
          return false;
        case 38:
          return moveCursor('up', null, true, true);
        case 40:
          return moveCursor('down', null, true, true);
        case 39:
          return moveCursor('right', null, true, true);
        case 37:
          return moveCursor('left', null, true, true);
        case 8:
          moveCursor('left', null);
          state.selectedCell.clear();
          return setCursor(state.selectedCell);
        case 13:
          t = moveCursor('down', state.lastClickCell, true);
          return state.lastClickCell = t;
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
          var km, latlng, result;
          result = data['ResultSet']['Results'][0];
          latlng = new L.LatLng(parseFloat(result.latitude), parseFloat(result.longitude));
          km = latlng.distanceTo(state.geoPos) / 1000;
          if (km <= config.maxJumpDistance()) {
            map.panTo(latlng);
            state.geoPos = latlng;
          } else if (config.isAuth()) {
            state.isLocal = false;
            map.panTo(latlng);
            state.geoPos = latlng;
            now.isLocal = false;
          } else {
            insertMessage('Too Far!', "Sorry, you can't jump that far.  Register to go wherever you want.");
          }
          $('#locationSearch').modal('hide');
          return centerCursor();
        }
      });
      return false;
    });
    $("a#makeLink").click(function() {
      if (!config.isAuth()) {
        insertMessage('Register', 'If you want to add links', "alert-error");
        return false;
      } else {
        return true;
      }
    });
    $("#linkModal").submit(function() {
      var url;
      $('#linkModal').modal('hide');
      url = $("#linkurl").val();
      state.linkurl = url;
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
      var action, c, f, payload, t, text, type;
      action = $(this).data('action');
      type = $(this).data('type');
      payload = $(this).data('payload');
      text = $(this).text();
      $(this).parent().parent().find('.active').removeClass('active');
      $(this).parent().addClass('active');
      if (type === 'geoLink') {
        now.createGeoLink(state.selectedCell.key.slice(1), map.getZoom());
      }
      if (action === 'hide' && type === 'notes') {
        $('#notes').slideToggle();
      }
      if (action === 'set') {
        state[type] = payload;
        now.setServerState(type, payload);
      }
      if (action === 'setClientState') {
        state[type] = payload;
      }
      if (action === 'goto') {
        goToCell(payload, map.getZoom());
      }
      if (action === 'show' && type === 'notes') {
        $('#notes').slideToggle().find('.loading').load("/notes/" + payload);
        $("#notes li").removeClass('active');
        $("#notes li." + payload).addClass('active');
        if (payload === 'unread') {
          $(this).find('i').removeClass('hasUnread');
        }
        return false;
      }
      if (action === 'get' && type === 'notes') {
        $('#notes .loading').load("/notes/" + payload);
        $("#notes li").removeClass('active');
        $("#notes li." + payload).addClass('active');
        return false;
      }
      if (action === 'get' && type === 'info') {
        now.getCellInfo();
        return false;
      }
      if (type === 'writeDirection') {
        c = this.innerHTML;
        $('.direction-dropdown')[0].innerHTML = c;
        $('.direction-dropdown i').addClass('icon-white');
      }
      if (type === 'submitfeedback') {
        f = $('#feedback').val();
        t = $("#t").val();
        now.submitFeedback(f, t);
        $('#feedbackModal').modal('hide');
        inputEl.focus();
        return false;
      }
      inputEl.focus();
    });
  };

  panIfAppropriate = function(direction, force) {
    var panByDist, panOnDist, selectedPP;
    selectedPP = $(state.selectedEl).offset();
    panOnDist = 120;
    if (direction === 'left' || direction === 'right') {
      panByDist = config.tileSize().x;
      if (force) {
        panByDist = state.cellWidth();
      }
    } else {
      panByDist = config.tileSize().y / 2;
      if (force) {
        panByDist = state.cellHeight();
      }
    }
    if (direction === 'up') {
      if (selectedPP.top < panOnDist) {
        pan(0, 0 - panByDist);
      }
    }
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
      if (selectedPP.left < panOnDist) {
        return pan(0 - panByDist, 0);
      }
    }
  };

  jQuery(function() {
    var centerPoint, mapOptions, tileServeLayer;
    if (!config.isAuth()) {
      welcome();
    }
    if (!window.NOMAP) {
      tileServeLayer = new L.TileLayer(config.tileServeUrl(), {
        maxZoom: config.maxZoom()
      });
    } else {
      tileServeLayer = new L.TileLayer('', {
        maxZoom: config.maxZoom()
      });
    }
    centerPoint = window.officialCities["New York City"];
    mapOptions = {
      center: centerPoint,
      attributionControl: false,
      zoom: config.defZoom(),
      scrollWheelZoom: config.scrollWheelZoom(),
      minZoom: config.minZoom(),
      maxZoom: config.maxZoom() - window.MapBoxBadZoomOffset
    };
    window.map = new L.Map('map', mapOptions).addLayer(tileServeLayer);
    map.preZoom = function(zoomDelta, cb) {
      var current;
      current = map.getZoom();
      if (zoomDelta > 0) {
        if (current <= config.minLayerZoom() && state.isTopLayerInteractive) {
          layerUtils.remove(state.topLayerStamp);
          $.doTimeout(200, function() {
            layerUtils.addCanvas();
            return false;
          });
          insertMessage('No Writing', " You've zoomed out too far to write. Zoom back in to write again.");
        }
      } else if (zoomDelta < 0) {
        if (current >= config.minLayerZoom() - 1 && !state.isTopLayerInteractive) {
          layerUtils.remove(state.topLayerStamp);
          layerUtils.addDom();
        }
      }
      if (current === config.minZoom() + 1 && zoomDelta > 0) {
        insertMessage('Zoomed Out', "That's as far as you can zoom out right now.");
        return false;
      }
      cb();
    };
    state.geoLinked = window.location.hash.slice(1);
    initializeGeo();
    now.ready(function() {
      doNowInit(now);
    });
    return true;
  });

  doNowInit = function(now) {
    var domTiles;
    domTiles = new L.DomTileLayer({
      tileSize: config.tileSize()
    });
    state.topLayerStamp = L.Util.stamp(domTiles);
    now.isLocal = state.isLocal;
    now.numRC = state.numRows();
    now.setGroup(initialWorldId);
    now.currentWorldId = initialWorldId;
    now.personalWorldId = personalWorldId;
    map.addLayer(domTiles);
    $.doTimeout(2000, function() {
      if (!state.selectedCell) {
        return true;
      } else {
        $.doTimeout(4000, function() {
          now.getCursors();
          return false;
        });
        return false;
      }
    });
    setTileStyle();
    map.on('zoomend', function() {
      setTileStyle();
      now.numRC = state.numRows();
      return $('.leaflet-tile a').tooltip({
        placement: 'top'
      });
    });
    initializeInterface();
    $("#loadingIndicator").fadeOut('slow');
    now.setBounds(domTiles.getTilePointAbsoluteBounds());
    now.core.socketio.on('disconnect', function() {
      $("#errorIndicator").fadeIn('fast');
      return $.doTimeout(2000, function() {
        return location.reload();
      });
    });
    map.on('moveend', function(e) {
      if (state.topLayerStamp) {
        now.setBounds(getLayer(state.topLayerStamp).getTilePointAbsoluteBounds());
      }
      return $("#loadingIndicator").fadeOut('slow');
    });
    now.setClientStateFromServer(function(s) {
      state.userPowers = s.powers;
      if (s.color) {
        state.color = s.color;
        return $('#colorPicker').colorpicker("option", "color", s.color);
      } else {
        state.color = config.colorOptions[Math.floor(Math.random() * 8)];
        $('#colorPicker').colorpicker("option", "color", state.color);
        return now.setServerState('color', state.color);
      }
    });
    centerCursor();
    now.goTo = function(latlng) {
      map.panTo(latlng);
    };
    now.updateCursors = function(updatedCursor) {
      var cursor, selectedCell;
      if (state.cursors[updatedCursor.cid]) {
        cursor = state.cursors[updatedCursor.cid];
        selectedCell = Cell.get(cursor.x, cursor.y);
        if (selectedCell) {
          selectedCell.cursor(false);
        }
      }
      state.cursors[updatedCursor.cid] = updatedCursor;
      cursor = updatedCursor;
      if (cursor.x && cursor.y) {
        selectedCell = Cell.get(cursor.x, cursor.y);
        if (selectedCell) {
          selectedCell.cursor(cursor.color);
        }
      } else {
        delete state.cursors[cursor.cid];
      }
    };
    $("#getNearby").click(function() {
      now.getCloseUsers(function(closeUsers) {
        var cellPoint, user, _i, _len, _results;
        $("#nearby").empty();
        if (closeUsers.length === 0) {
          $("ul#nearby").append(function() {
            return $("<li> <a>Sorry, no one is nearby. </a> <small> Or they're too zoomed out to count.</small></li>");
          });
          return false;
        }
        cellPoint = cellKeyToXY(state.selectedCell.key);
        _results = [];
        for (_i = 0, _len = closeUsers.length; _i < _len; _i++) {
          user = closeUsers[_i];
          user.radians = Math.atan2(cellPoint.y - user.cursor.y, cellPoint.x - user.cursor.x);
          user.degrees = user.radians * (180 / Math.PI);
          if (user.radians < 0) {
            user.degrees = 360 + user.degrees;
          }
          if (!user.login) {
            user.login = 'Someone';
          }
          _results.push($("ul#nearby").append(function() {
            var arrow;
            return arrow = $("<li><a class='trigger' data-action='goto' data-payload='" + (user.cursor.x - 1) + "x" + (user.cursor.y - 1) + "'><i class='icon-arrow-left' style='-moz-transform: rotate(" + user.degrees + "deg);-webkit-transform: rotate(" + user.degrees + "deg);'></i> " + user.login + "</a></li>");
          }));
        }
        return _results;
      });
    });
    now.drawRite = function(commandType, rite, cellPoint, cellProps) {
      var c;
      c = Cell.get(cellPoint.x, cellPoint.y);
      return c[commandType](rite, cellProps);
    };
    return now.insertMessage = function(heading, message, cssclass, timing) {
      if (timing == null) {
        timing = 6;
      }
      return insertMessage(heading, message, cssclass, timing);
    };
  };

  window.insertMessage = function(heading, message, cssclass, timing) {
    var html;
    if (cssclass == null) {
      cssclass = "";
    }
    if (timing == null) {
      timing = 6;
    }
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

    Cell.name = 'Cell';

    all = {};

    Cell.all = function() {
      return all;
    };

    Cell.get = function(x, y) {
      return all["c" + x + "x" + y];
    };

    Cell.killAll = function() {
      return all = {};
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
      var $span, span;
      this.row = row;
      this.col = col;
      this.tile = tile;
      this.contents = contents != null ? contents : config.defaultChar();
      this.props = props != null ? props : {};
      this.events = events != null ? events : null;
      this.key = this.generateKey();
      all[this.key] = this;
      this.span = document.createElement('span');
      this.span.innerHTML = this.contents;
      if (this.props.linkurl) {
        $(this.span).addClass('link');
        this.span.innerHTML = "<a href='" + this.props.linkurl + "' TARGET='_blank' rel='tooltip' title='" + this.props.linkurl + "'>" + this.contents + "</a>";
      }
      this.span.id = this.key;
      $(this.span).addClass('cell');
      if (!this.props.color) {
        this.props.color = 'c0';
      }
      this.span.style.color = "#" + this.props.color;
      if (this.props.echoes) {
        $(this.span).addClass("e" + this.props.echoes);
      }
      this.watch("contents", function(id, oldval, newval) {
        this.span.innerHTML = newval;
        return newval;
      });
      $span = $(this.span);
      span = this.span;
      this.props.watch("echoes", function(id, oldval, newval) {
        $span.removeClass('e' + oldval);
        $span.addClass('e' + newval);
        return newval;
      });
      this.props.watch("color", function(id, oldval, newval) {
        span.style.color = "#" + newval;
        return newval;
      });
    }

    Cell.prototype.write = function(c) {
      var cellPoint, contents;
      cellPoint = cellKeyToXY(this.key);
      if (state.linkurl) {
        contents = {
          contents: c,
          linkurl: state.linkurl
        };
        now.writeCell(cellPoint, contents);
        state.linkurl = false;
        now.setServerState('linked', true);
      } else {
        now.writeCell(cellPoint, c);
      }
    };

    Cell.prototype.cursor = function(color) {
      if (color) {
        this.span.style.backgroundColor = '#' + color;
        this.span.className += ' otherSelected ';
      } else {
        this.span.style.backgroundColor = '';
        $(this.span).removeClass('otherSelected');
      }
    };

    Cell.prototype.normalRite = function(rite, cellProps) {
      this.contents = rite.contents;
      this.props.color = rite.props.color;
      if (rite.props.linkurl) {
        this.props.linkurl = rite.props.linkurl;
        $(this.span).addClass('link');
        return this.span.innerHTML = "<a href='" + this.props.linkurl + "' TARGET='_blank' rel='tooltip' title='" + this.props.linkurl + "'>" + this.contents + "</a>";
      }
    };

    Cell.prototype.echo = function(rite, cellProps) {
      this.props.echoes = cellProps.echoes;
      this.animateText(1);
      return this.props.color = cellProps.color;
    };

    Cell.prototype.overrite = function(rite, cellProps) {
      this.animateTextRemove();
      this.contents = rite.contents;
      this.props.echoes = 0;
      return this.props.color = rite.props.color;
    };

    Cell.prototype.downrote = function(rite, cellProps) {
      $(this.span).removeClass('e' + this.props.echoes);
      this.props.echoes -= 1;
      this.props.color = cellProps.color;
      return shakeWindow(1);
    };

    Cell.prototype.kill = function() {
      this.span = null;
      return delete all[this.key];
    };

    Cell.prototype.clear = function() {
      return this.write(config.defaultChar());
    };

    Cell.prototype.animateTextInsert = function(c, animateWith, color, welcome) {
      var clone, offset, span;
      if (color == null) {
        color = state.color;
      }
      if (welcome == null) {
        welcome = false;
      }
      clone = document.createElement('SPAN');
      clone.className = 'cell ' + color;
      clone.innerHTML = c;
      span = this.span;
      if (!animateWith) {
        animateWith = Math.floor(Math.random() * 3) + 1;
      }
      $(clone).css('position', 'absolute').insertBefore('body').addClass('ai' + animateWith);
      offset = $(this.span).offset();
      $(clone).css({
        'opacity': '1 !important',
        'font-size': '1em'
      });
      $(clone).css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      });
      if (!welcome) {
        return $(clone).doTimeout(200, function() {
          span.innerHTML = c;
          span.className += " " + color + " ";
          $(clone).remove();
          return false;
        });
      }
    };

    Cell.prototype.animateText = function(animateWith) {
      var clone, offset, span;
      if (animateWith == null) {
        animateWith = 0;
      }
      span = this.span;
      clone = $(this.span).clone();
      offset = $(this.span).position();
      $(this.span).after(clone);
      $(clone).removeClass('selected');
      $(clone).addClass('aa').css({
        'position': 'absolute',
        left: offset.left,
        top: offset.top
      }).hide();
      $(clone).queue(function() {
        $(this).show().css({
          'fontSize': '+=90',
          'marginTop': "-=45",
          'marginLeft': "-=45"
        });
        return $(this).dequeue();
      });
      return $(clone).doTimeout(400, function() {
        $(this).css({
          'fontSize': '-=90',
          'marginTop': 0,
          'marginLeft': 0
        });
        this.doTimeout(400, function() {
          $(span).show();
          return $(clone).remove();
        });
        return false;
      });
    };

    Cell.prototype.animateTextRemove = function(animateWith) {
      var clone, offset, span;
      if (!animateWith) {
        animateWith = Math.floor(Math.random() * 3) + 1;
      }
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
        if (animateWith) {
          $(this).addClass('ar' + animateWith);
        }
        return $(this).dequeue();
      });
      return $(clone).doTimeout(800, function() {
        $(clone).remove();
        return false;
      });
    };

    Cell.getOrCreate = function(row, col, tile, contents, props) {
      var cell, x, y;
      if (contents == null) {
        contents = null;
      }
      if (props == null) {
        props = {};
      }
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

  layerUtils = {
    remove: function(stamp) {
      var layer;
      layer = map._layers[stamp];
      map.removeLayer(layer);
    },
    addCanvas: function() {
      var canvasTiles;
      canvasTiles = new L.WCanvas({
        tileSize: {
          x: 192,
          y: 256
        }
      });
      map.addLayer(canvasTiles);
      state.isTopLayerInteractive = false;
      state.topLayerStamp = L.Util.stamp(canvasTiles);
      state.selectedCell = null;
      state.lastClickCell = null;
      now.setBounds(false);
    },
    addDom: function() {
      var domTiles;
      map.options.zoomAnimation = false;
      domTiles = new L.DomTileLayer({
        tileSize: config.tileSize()
      });
      map.addLayer(domTiles);
      state.topLayerStamp = L.Util.stamp(domTiles);
      state.isTopLayerInteractive = true;
      now.setBounds(domTiles.getTilePointAbsoluteBounds());
      inputEl.focus();
      centerCursor();
      $.doTimeout(1000, function() {
        map.options.zoomAnimation = true;
        return false;
      });
    }
  };

  welcome = function() {
    var c, welcome_cells, welcome_message, _i, _len, _ref;
    welcome_message = [];
    _ref = "Hey. Try typing on the map./It'll be fun. I swear. // You can move around with the mouse and arrow keys. ";
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      c = _ref[_i];
      welcome_message.push(c);
    }
    welcome_cells = [];
    return $.doTimeout(10000, function() {
      var initial_x, key, layer, target, targetCell;
      $('.cS0').live('click', function() {
        $.doTimeout('welcome');
        return $('.cS0').addClass('ar1').doTimeout(200, function() {
          return this.remove();
        });
      });
      map.on('movestart', function() {
        $('.cS0').addClass('ar1').doTimeout(200, function() {
          return this.remove();
        });
        return $.doTimeout('welcome');
      });
      inputEl.keypress(function(e) {
        $('.cS0').addClass('ar1').doTimeout(200, function() {
          return this.remove();
        });
        return $.doTimeout('welcome');
      });
      layer = getLayer(state.topLayerStamp);
      if (!layer) {
        return true;
      }
      target = layer.getCenterTile();
      target.x -= 15;
      target.y -= 10;
      initial_x = target.x;
      key = "c" + target.x + "x" + target.y;
      targetCell = Cell.all()[key];
      if (!targetCell) {
        return true;
      }
      $.doTimeout('welcome', 120, function() {
        var l;
        l = welcome_message.shift();
        if (l === '/') {
          target.y += 1;
          target.x = initial_x;
        } else {
          target.x += 1;
          key = "c" + target.x + "x" + target.y;
          targetCell = Cell.all()[key];
          targetCell.animateTextInsert(l, 99, 'cS0', true);
          welcome_cells.push(targetCell);
        }
        if (welcome_message.length) {
          return true;
        } else {
          $.doTimeout(8000, function() {
            $('.cS0').addClass('ar1').doTimeout(200, function() {
              return this.remove();
            });
            return false;
          });
          return false;
        }
      });
      return false;
    });
  };

  getLayer = function(stamp) {
    return map._layers[stamp];
  };

  window.shakeWindow = function(s) {
    var b, options;
    if (s == null) {
      s = 1;
    }
    b = $('body');
    options = {
      x: 2 + s / 2,
      y: 2 + s / 2,
      rotation: s / 2,
      speed: 18 - s * 3
    };
    b.jrumble(options);
    b.trigger('startRumble');
    b.doTimeout(500, function() {
      b.trigger('stopRumble');
      return false;
    });
    return true;
  };

  pan = function(x, y) {
    var p;
    p = new L.Point(x, y);
    map.panBy(p);
    return map;
  };

  window.goToCell = function(key, zoom) {
    var cHeight, cWidth, latlng, numRC, pixelX, pixelY, x, y, z, zoomDiff, _ref, _ref1;
    if (zoom == null) {
      zoom = false;
    }
    if (!zoom) {
      _ref = key.split('x'), z = _ref[0], x = _ref[1], y = _ref[2];
    } else {
      _ref1 = key.split('x'), x = _ref1[0], y = _ref1[1];
      z = zoom;
    }
    zoomDiff = config.maxZoom() - z;
    numRC = Math.pow(2, zoomDiff);
    cWidth = config.tileSize().x / numRC;
    cHeight = config.tileSize().y / numRC;
    pixelX = x * cWidth;
    pixelY = y * cHeight;
    latlng = map.unproject({
      x: pixelX,
      y: pixelY
    }, z);
    map.setView(latlng, z);
    $.doTimeout(200, function() {
      var cell;
      cell = Cell.get(x, y);
      if (!cell) {
        return true;
      } else {
        setCursor(cell);
        return false;
      }
    });
    return latlng;
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
      if (func(x)) {
        _results.push(x);
      }
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
