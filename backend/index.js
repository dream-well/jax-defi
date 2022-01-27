import cp from 'child_process'

let onExit = (number, signal) => {
    console.log(`Error number ${number}, ${signal}`);
    cp.fork('./src/index.js').on('exit', onExit);
}

cp.fork('./src/index.js').on('exit', onExit);
