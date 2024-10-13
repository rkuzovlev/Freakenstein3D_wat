const GAME_WIDTH = 240
const GAME_HEIGHT = 240

const gameCanvas = document.getElementById('game')
const gameContext = gameCanvas.getContext('2d')
const b = document.getElementsByTagName('body')[0]

gameCanvas.width = GAME_WIDTH
gameCanvas.height = GAME_HEIGHT

async function loadGame() {
    const response = await fetch('./game.png')
    const imgArrayBuffer = await response.arrayBuffer()

    const imgBlob = new Blob( [ imgArrayBuffer ], { type: "image/png" } )
    const imgURL = URL.createObjectURL(imgBlob)
    
    const img = new Image()
    img.src = imgURL
    img.onload = async function() {
        const canvas = new OffscreenCanvas(img.width, img.height)
        const context = canvas.getContext('2d')
        
        context.drawImage(img, 0, 0)

        const imgData = context.getImageData(0, 0, img.width, img.height)
        
        const imgDataView = new DataView(imgData.data.buffer)
        const bodyLength = imgDataView.getUint16(0)
        const wasmLength = imgDataView.getUint16(4)

        const componentsCount = Math.ceil(bodyLength / 4)
        const components = []

        const wasmDataWithAlpha = imgData.data.buffer.slice(8, bodyLength + 8)
        for (let i = 0; i < componentsCount; ++i){
            components.push(wasmDataWithAlpha.slice(i*4, i*4+3))
        }

        const componentsBlob = new Blob(components, { type: 'application/octet-stream' })
        const wasmDataBuffer = await componentsBlob.arrayBuffer()
        const wasmData = wasmDataBuffer.slice(0, wasmLength)

        // const { instance, module } = await WebAssembly.instantiate(wasmData)
        const { instance, module } = await WebAssembly.instantiateStreaming(fetch('./game.wasm'))
    
        console.log({ instance, module })

        const { frame, render, init } = instance.exports
        
        console.log('frame', frame)

        init(GAME_WIDTH, GAME_HEIGHT)

        const bufferSize = GAME_WIDTH * GAME_HEIGHT * 4

        function animate(){
            render()

            const bufferArray = new Uint8ClampedArray(frame.buffer, 0, bufferSize)
            const image = new ImageData(bufferArray, GAME_WIDTH, GAME_HEIGHT)
            gameContext.putImageData(image, 0, 0)

            requestAnimationFrame(animate)
        }

        requestAnimationFrame(animate)

        // let interval = null
        // b.addEventListener('keydown', (e) => { if (e.key === " " && !interval) interval = setInterval(animate, 50); })
        // b.addEventListener('keyup', () => { clearInterval(interval); interval = null })
        // b.addEventListener('click', animate)
    }
}

loadGame()
