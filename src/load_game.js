const GAME_WIDTH = 240
const GAME_HEIGHT = 240

const gameCanvas = document.getElementById('game')
const gameContext = gameCanvas.getContext('2d')
const body = document.getElementsByTagName('body')[0]

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


        function log(number){
            console.log('wasm', number)
        }

        const exportFunctions = {
            common: { log },
            Math: Math
        }

        // const { instance, module } = await WebAssembly.instantiate(wasmData)
        const { instance, module } = await WebAssembly.instantiateStreaming(fetch('./game.wasm'), exportFunctions)
    
        console.log({ instance, module })

        const { frame, render, update, init, playerX, playerY, FOV } = instance.exports
        
        console.log('frame', frame)

        init(GAME_WIDTH, GAME_HEIGHT)

        const bufferSize = GAME_WIDTH * GAME_HEIGHT * 4

        
        let rotationAngle = Math.PI
        let w = 0, a = 0, s = 0, d = 0

        const MAP_DRAW_MULTILPLIER = 20
        const MAP_PADDING = 10
        const MAP_WIDTH = 5
        const MAP_HEIGHT = 5
        const map = [
            "#", "#", "#", "#", "#", 
            "#", ".", ".", ".", "#", 
            "#", ".", "#", ".", "#", 
            "#", ".", ".", ".", "#", 
            "#", "#", "#", "#", "#", 
        ]

        function drawCell(cellX, cellY, type){
            const x = cellX * MAP_DRAW_MULTILPLIER + MAP_PADDING
            const y = cellY * MAP_DRAW_MULTILPLIER + MAP_PADDING
            
            gameContext.fillStyle = "#ddddddaa"
            gameContext.strokeStyle = "#333333aa"
            gameContext.beginPath()
            gameContext.rect(x, y, MAP_DRAW_MULTILPLIER, MAP_DRAW_MULTILPLIER)
            switch (type) {
                case "#": {
                    gameContext.fill()
                    gameContext.stroke()
                    break
                }
                default: gameContext.stroke()
            }
        }

        function renderCells(){
            map.forEach((cell, i) => {
                const cx = i % MAP_WIDTH
                const cy = Math.floor(i / MAP_WIDTH)
                drawCell(cx, cy, cell)
            })
        }

        function drawPlayer(){
            const px = playerX.value * MAP_DRAW_MULTILPLIER + MAP_PADDING
            const py = playerY.value * MAP_DRAW_MULTILPLIER + MAP_PADDING

            gameContext.fillStyle = "#00ff00"
            gameContext.strokeStyle = "#000000"
            gameContext.beginPath()
            gameContext.arc(px, py, 5, 0, Math.PI * 2, true)
            gameContext.fill()
            gameContext.stroke()

            const halfFOV = FOV.value / 2
            const fovLeft = rotationAngle - halfFOV
            const fovLeftX = Math.sin(fovLeft) * MAP_DRAW_MULTILPLIER * 3 + px
            const fovLeftY = Math.cos(fovLeft) * MAP_DRAW_MULTILPLIER * 3 + py

            const fovRight = rotationAngle + halfFOV
            const fovRightX = Math.sin(fovRight) * MAP_DRAW_MULTILPLIER * 3 + px
            const fovRightY = Math.cos(fovRight) * MAP_DRAW_MULTILPLIER * 3 + py

            gameContext.fillStyle = "#ff000050"
            gameContext.beginPath()
            gameContext.moveTo(px, py)
            gameContext.lineTo(fovLeftX, fovLeftY)
            gameContext.lineTo(fovRightX, fovRightY)
            gameContext.moveTo(px, py)
            gameContext.fill()
        }

        function renderMap(){
            renderCells()
            drawPlayer()
        }

        let lastFrame = performance.now()
        function animate(){
            const now = performance.now()
            const deltaTime = ((now - lastFrame) / 1000).toFixed(4)
            // console.log('deltaTime', deltaTime, playerX.value, playerY.value)
            update(deltaTime, w, a, s, d)
            render()
            lastFrame = now

            const bufferArray = new Uint8ClampedArray(frame.buffer, 0, bufferSize)
            const image = new ImageData(bufferArray, GAME_WIDTH, GAME_HEIGHT)
            gameContext.putImageData(image, 0, 0)

            renderMap()

            requestAnimationFrame(animate)
        }

        requestAnimationFrame(animate)

        body.addEventListener('keydown', (e) => { 
            if (e.key === 'w') w = 1
            if (e.key === 'a') a = 1
            if (e.key === 's') s = 1
            if (e.key === 'd') d = 1
        })

        body.addEventListener('keyup', (e) => { 
            if (e.key === 'w') w = 0
            if (e.key === 'a') a = 0
            if (e.key === 's') s = 0
            if (e.key === 'd') d = 0
        })

        body.addEventListener('mousemove', (e) => { 
            rotationAngle = 2 * Math.PI * (-e.clientX / 600)
        })
    }
}

loadGame()
