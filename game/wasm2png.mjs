import fs from 'node:fs'
import { createCanvas, ImageData } from 'canvas'

const IMAGE_WIDTH = 100
const HEADER_SIZE = 8

async function pack(){
    const wasm = fs.readFileSync('game/game.wasm')

    const slicedWasm = []
    const slicedCount = Math.ceil(wasm.byteLength / 3)
    for (let i = 0; i < slicedCount; ++i){
        slicedWasm.push(wasm.subarray(i*3, i*3+3))
        if (i < slicedCount - 1){
            slicedWasm.push(new Uint8Array([255]))
        } else {
            const restBytesCount = 4 - (wasm.byteLength % 3)
            slicedWasm.push(new Uint8Array(Array(restBytesCount).fill(255)))
        }
    }

    const preparedWasmBlob = new Blob(slicedWasm, { type: 'application/octet-stream' })
    const preparedWasm = await preparedWasmBlob.arrayBuffer()
    
    const headerArrayBuffer = new ArrayBuffer(HEADER_SIZE)
    const headerDataView = new DataView(headerArrayBuffer)
    headerDataView.setUint16(0, preparedWasm.byteLength)
    headerDataView.setUint8(2, 255)
    headerDataView.setUint8(3, 255)
    headerDataView.setUint16(4, wasm.byteLength)
    headerDataView.setUint8(6, 255)
    headerDataView.setUint8(7, 255)

    const overalByteLength = preparedWasm.byteLength + HEADER_SIZE
    const pixelsCount = Math.ceil(overalByteLength / 4)
    const IMAGE_HEIGHT = Math.ceil(pixelsCount / IMAGE_WIDTH)

    const imageBlob = new Blob([ headerArrayBuffer, preparedWasm ], { type: 'application/octet-stream' })

    const imageBuffer = await imageBlob.arrayBuffer()
    const imageUI8 = new Uint8ClampedArray(imageBuffer)

    const wasmImageData = new ImageData(imageUI8, IMAGE_WIDTH, IMAGE_HEIGHT)

    const canvas = createCanvas(IMAGE_WIDTH, IMAGE_HEIGHT)
    const context = canvas.getContext('2d')
    context.putImageData(wasmImageData, 0, 0)
    
    const pngBuffer = canvas.toBuffer('image/png', { compressionLevel: 9, filters: canvas.PNG_NO_FILTERS })

    fs.writeFileSync('game/game.png', pngBuffer)
}

pack()
