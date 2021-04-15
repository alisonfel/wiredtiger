#!/usr/bin/env node

/**
 * multiplex.js
 * https://github.com/chjj/blessed
 * Copyright (c) 2013-2015, Christopher Jeffrey (MIT License)
 * A terminal multiplexer created by blessed.
 */

process.title = 'multiplex.js';

var blessed = require('blessed')
, screen;

const {spawnSync} = require('child_process');

var statConfig = {};

function findSymbols() {
    const findSymbolsExec = spawnSync('python3', [
        '../find_symbols.py', '-l',
        '/home/alexc/work/wiredtiger/build_posix/.libs/libwiredtiger.so']);
    const functionTxt = findSymbolsExec.stdout.toString();
    var functionList = functionTxt.split('\n');
    functionList.forEach(function(f) {
        statConfig[f] = {
            'latency': false,
            'frequency': false,
            'stack': false,
        };
    });
    return functionList;
}

screen = blessed.screen({
  smartCSR: true,
  log: process.env.HOME + '/blessed-terminal.log',
  fullUnicode: true,
  dockBorders: true,
  ignoreDockContrast: true
});

var topleft = blessed.list({
  parent: screen,
  keys: true,
  vi: true,
  label: ' WiredTiger Symbols',
  left: 0,
  top: 0,
  width: '50%',
  height: '100%',
  border: 'line',
  style: {
    fg: 'default',
    bg: 'default',
    focus: {
      border: {
        fg: 'green'
      }
    }
  },
  tags: true,
  invertSelected: false,
    items: findSymbols(),
  scrollbar: {
    ch: ' ',
    track: {
      bg: 'yellow'
    },
    style: {
      inverse: true
    }
  },
  style: {
    item: {
      hover: {
        bg: 'blue'
      }
    },
    selected: {
      bg: 'blue',
      bold: true
    },
  },
  search: function(callback) {
    prompt.input('Search:', '', function(err, value) {
      if (err) return;
      return callback(null, value);
    });
  }
});

var prompt = blessed.prompt({
  parent: topleft,
  top: 'center',
  left: 'center',
  height: 'shrink',
  width: 'shrink',
  keys: true,
  vi: true,
  mouse: true,
  tags: true,
  border: 'line',
  hidden: true
});


var topright = blessed.list({
    parent: screen,
    keys: true,
    vi: true,
  label: ' Statistics',
  left: '50%',
  top: 0,
  width: '50%',
  height: '15%',
    border: 'line',
    items: [
        'latency',
        'frequency',
        'stack'
    ],
    style: {
        item: {
            hover: {
                bg: 'blue'
            }
        },
        selected: {
            bg: 'blue',
            bold: true
        },
    },
});

var bottomright = blessed.log({
  parent: screen,
  label: ' Trace Output ',
  left: '50%',
  top: '15%',
  width: '50%',
  height: '86%',
  border: 'line',
  style: {
    fg: 'default',
    bg: 'default',
    focus: {
      border: {
        fg: 'green'
      }
    }
  },
  tags: true,
  keys: true,
  vi: true,
  mouse: true,
  scrollback: 100,
  scrollbar: {
    ch: ' ',
    track: {
      bg: 'yellow'
    },
    style: {
      inverse: true
    }
  }
});

setInterval(function() {
  bottomright.log('Hello {#0fe1ab-fg}world{/}: {bold}%s{/bold}.', Date.now().toString(36));
  if (Math.random() < 0.30) {
    bottomright.log({foo:{bar:{baz:true}}});
  }
  screen.render();
}, 1000).unref();

[topleft, topright, bottomright].forEach(function(term) {
  term.enableDrag(function(mouse) {
    return !!mouse.ctrl;
  });
  term.on('title', function(title) {
    screen.title = title;
    term.setLabel(' ' + title + ' ');
    screen.render();
  });
  term.on('click', term.focus.bind(term));
});

topleft.on('keypress', function(ch, key) {
    if (key.name == 'right') {
        topright.focus();
    }
});

topright.on('keypress', function(ch, key) {
    if (key.name == 'left') {
        topleft.focus();
    } else if (key.name == 'space') {
        // TODO: Add more stuff lol.
    }
});

topleft.focus();

screen.key('C-q', function() {
  topright.kill();
  bottomright.kill();
  return screen.destroy();
});

screen.program.key('C-n', function() {
  screen.focusNext();
  screen.render();
});

screen.render();
