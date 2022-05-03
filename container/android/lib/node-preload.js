const cp = require('child_process')
const ChildProcess = cp.ChildProcess
const spawnSyncBinding = process.binding('spawn_sync')
const fs = require("fs");

const spawn = ChildProcess.prototype.spawn
const spawnSync = spawnSyncBinding.spawn

spawnSyncBinding.spawn = wrappedSpawnFunction(spawnSync)
ChildProcess.prototype.spawn = wrappedSpawnFunction(spawn)


function wrappedSpawnFunction(fn) {
    return wrappedSpawn

    function wrappedSpawn(options) {
        options = options || {};
        const envPairs = options.envPairs || [];
        envPairs.push(`LD_PRELOAD=${process.env.LD_PRELOAD}`);
        options.envPairs = envPairs;
        return fn.call(this, options)
    }
}

( // https://github.com/nodejs/node/issues/40200
    (origFn) => {
        //https://github.com/xxorax/node-shell-escape/blob/master/shell-escape.js
        const shellescape = function (a) {
            var ret = [];
          
            a.forEach(function(s) {
              if (/[^A-Za-z0-9_\/:=-]/.test(s)) {
                s = "'"+s.replace(/'/g,"'\\''")+"'";
                s = s.replace(/^(?:'')+/g, '') // unduplicate single-quote at the beginning
                  .replace(/\\'''/g, "\\'" ); // remove non-escaped single-quote if there are enclosed between 2 escaped
              }
              ret.push(s);
            });
          
            return ret.join(' ');
          }
        fs.copyFileSync = function(...args) {
            if(args.length===2 && typeof args[0]==='string' && typeof args[1]==='string') {
                cp.execSync(shellescape(["cp", "-f", args[0], args[1]]));
            } else {
                return origFn.call(this, ...args);
            }
        }
    }
)(fs.copyFileSync);