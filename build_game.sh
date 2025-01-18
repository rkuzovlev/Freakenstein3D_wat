#!/bin/bash

if [ ! -d game/build ]; then
    mkdir game/build
fi

node game/sprite_packer.mjs
./node_modules/.bin/wat2wasm game/build/game.wat_prepared -o game/build/game.wasm --enable-multi-memory
node game/wasm2png.mjs
cp game/index.html game/build
cp game/game.js game/build
cp game/loader.js game/build