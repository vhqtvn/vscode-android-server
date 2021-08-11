const cp = require('child_process')
const ChildProcess = cp.ChildProcess
const spawnSyncBinding = process.binding('spawn_sync')

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