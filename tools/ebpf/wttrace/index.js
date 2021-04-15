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

var net = require('net');
var udp = require('dgram');

const {spawnSync, spawn} = require('child_process');

var statConfig = {};

const statList = [
        'latency',
        'frequency',
        'stack'
];

const functionList = findSymbols();

function findSymbols() {
    const findSymbolsExec = spawnSync('python3', [
        '../find_symbols.py', '-l',
        '/home/alexc/work/wiredtiger/build_posix/.libs/libwiredtiger.so']);
    const functionTxt = findSymbolsExec.stdout.toString();
    var wtFunctions = functionTxt.split('\n');
    wtFunctions.forEach(function(f) {
        statConfig[f] = {
            'latency': false,
            'frequency': false,
            'stack': false,
        };
    });
    return wtFunctions;
}

function execEbpf(stat) {
    var statFunctions = [];
    for (const [k, v] of Object.entries(statConfig)) {
        if (v[stat]) {
            statFunctions.push(k);
        }
    }
    if (statFunctions.length == 0) {
        return null;
    }
    const spawnArgs = [
        '../wtebpf.py', '-l',
        '/home/alexc/work/wiredtiger/build_posix/.libs/libwiredtiger.so',
        '-a', '127.0.0.1', '-p', '8080', '-s', stat].concat(statFunctions);
    const runEbpf = spawn('python3', spawnArgs);
    return runEbpf;
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
    items: functionList,
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
    items: [].concat(statList),
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

var server = udp.createSocket('udp4');
server.on('error', function(error) {
    bottomright.log('error occured');
    server.close();
});
server.on('message', function(msg, info) {
    bottomright.log(msg.toString());
});
server.on('listening', function() {
    const address = server.address();
    bottomright.log('wttrace server is listening at address ' + address.address);
    bottomright.log('wttrace server is listening at port ' + address.port);
});
server.bind(8080, 'localhost');

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
    } else if (key.name == 'down' || key.name == 'j' || key.name == 'up' || key.name == 'k') {
        const wtFunction = functionList[topleft.selected];
        var counter = 0;
        for (const [k, v] of Object.entries(statConfig[wtFunction])) {
            if (v) {
                topright.items[counter].setContent(`*${k}`);
            } else {
                topright.items[counter].setContent(k);
            }
            counter++;
        }
    }
    screen.render();
});

topright.on('keypress', function(ch, key) {
    if (key.name == 'left') {
        topleft.focus();
    } else if (key.name == 'space') {
        // TODO: Add more stuff lol.
    }
});

topright.on('select', function(item, select) {
    const stat = statList[topright.selected];
    const wtFunction = functionList[topleft.selected];
    statConfig[wtFunction][stat] = !statConfig[wtFunction][stat];
    if (statConfig[wtFunction][stat]) {
        topright.items[topright.selected].setContent(`*${stat}`);
    } else {
        topright.items[topright.selected].setContent(stat);
    }
    const functionStats = statConfig[wtFunction];
    var hasStat = false;
    for (const [k, v] of Object.entries(functionStats)) {
        if (v) {
            hasStat = true;
            break;
        }
    }
    if (hasStat) {
        topleft.items[topleft.selected].setContent(`*${wtFunction}`);
    } else {
        topleft.items[topleft.selected].setContent(wtFunction);
    }
    screen.render();
});

topleft.focus();

var pids = [];

screen.key('C-q', function() {
    for (const pid of pids) {
        pid.kill('SIGINT');
    }
  return screen.destroy();
});

screen.program.key('C-n', function() {
  screen.focusNext();
  screen.render();
});

screen.key('C-r', function() {
    if (pids.length != 0) {
        return;
    }
    for (const stat of statList) {
        pid = execEbpf(stat);
        if (pid != null) {
            pids.push(pid);
        }
    }
});

screen.render();
