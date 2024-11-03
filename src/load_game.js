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

        const { 
            frame, 
            map, map_width, map_height,
            render, update, init, 
            player_x, player_y, 
            FOV 
        } = instance.exports
        
        console.log('memories', frame, map)

        init(GAME_WIDTH, GAME_HEIGHT)

        const bufferSize = GAME_WIDTH * GAME_HEIGHT * 4

        
        let playerAngleView = Math.PI
        let w = 0, a = 0, s = 0, d = 0

        const MAP_SIZE = map_width.value * map_height.value
        const MAP_BUFFER = new Uint8Array(map.buffer, 0, MAP_SIZE)
        const MAP_DRAW_MULTILPLIER = 20
        const MAP_PADDING = 70
        const MAP_MAX_LINES_INTERSECT_FIND = 4
        const WALL_CHAR_CODE = "#".charCodeAt(0)
        const FLOOR_CHAR_CODE = ".".charCodeAt(0)

        function drawCell(cellX, cellY, type){
            const x = cellX * MAP_DRAW_MULTILPLIER + MAP_PADDING
            const y = cellY * MAP_DRAW_MULTILPLIER + MAP_PADDING
            
            gameContext.fillStyle = "#ddddddaa"
            gameContext.strokeStyle = "#333333aa"
            gameContext.beginPath()
            gameContext.rect(x, y, MAP_DRAW_MULTILPLIER, MAP_DRAW_MULTILPLIER)
            switch (type) {
                case WALL_CHAR_CODE: {
                    gameContext.fill()
                    gameContext.stroke()
                    break
                }
                case FLOOR_CHAR_CODE: {
                    gameContext.stroke()
                    break
                }
                default: gameContext.stroke()
            }
        }

        function drawCells(){
            MAP_BUFFER.forEach((cell, i) => {
                const cx = i % map_width.value
                const cy = Math.floor(i / map_width.value)
                drawCell(cx, cy, cell)
            })
        }

        function drawPlayer(){
            const px = player_x.value * MAP_DRAW_MULTILPLIER + MAP_PADDING
            const py = player_y.value * MAP_DRAW_MULTILPLIER + MAP_PADDING

            gameContext.fillStyle = "#00ff00"
            gameContext.strokeStyle = "#000000"
            gameContext.beginPath()
            gameContext.arc(px, py, 5, 0, Math.PI * 2, true)
            gameContext.fill()
            gameContext.stroke()

            const halfFOV = FOV.value / 2
            const fovLeft = playerAngleView - halfFOV
            const fovLeftX = Math.sin(fovLeft) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + px
            const fovLeftY = Math.cos(fovLeft) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + py

            const fovRight = playerAngleView + halfFOV
            const fovRightX = Math.sin(fovRight) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + px
            const fovRightY = Math.cos(fovRight) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + py

            gameContext.fillStyle = "#ff000050"
            gameContext.beginPath()
            gameContext.moveTo(px, py)
            gameContext.lineTo(fovLeftX, fovLeftY)
            gameContext.lineTo(fovRightX, fovRightY)
            gameContext.moveTo(px, py)
            gameContext.fill()


            gameContext.strokeStyle = "#00000090"
            const centerLineX = Math.sin(playerAngleView) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + px
            const centerLineY = Math.cos(playerAngleView) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + py
            gameContext.beginPath()
            gameContext.moveTo(px, py)
            gameContext.lineTo(centerLineX, centerLineY)
            gameContext.stroke()
        }

        function drawIntersectionDot(x, y){
            gameContext.beginPath()
            gameContext.arc(x * MAP_DRAW_MULTILPLIER + MAP_PADDING, y * MAP_DRAW_MULTILPLIER + MAP_PADDING, 3, 0, Math.PI * 2, true)
            gameContext.fill()
        }

        function drawIntersections(){
            const vx = Math.sin(playerAngleView)
            const vy = Math.cos(playerAngleView)
            
            // console.log({ vx, vy })

            if (vx === 0 || vy === 0){
                return null
            }

            let lastNearDistance = Infinity
            let nearX = null
            let nearY = null
            function checkIntersection(x, y, vx, vy){
                // check distance of intersection
                const dvx = x - player_x.value
                const dvy = y - player_y.value
                const distance = Math.sqrt(dvx*dvx + dvy*dvy)
                const isNotTooFar = distance < MAP_MAX_LINES_INTERSECT_FIND
                const isNearThenBefore = distance < lastNearDistance
                const isDistanceOk = isNotTooFar && isNearThenBefore
    
                const checkCellX = Math.floor(x + vx)
                const checkCellY = Math.floor(y + vy)

                let isWall = false
                const cellXInRange = checkCellX >= 0 && checkCellX < map_width.value
                const cellYInRange = checkCellY >= 0 && checkCellY < map_height.value

                if (cellXInRange && cellYInRange){
                    const cellIndex = checkCellY * map_width.value + checkCellX
                    const cell = MAP_BUFFER[cellIndex]
                    isWall = cell === WALL_CHAR_CODE
                }

                if (isDistanceOk && isWall){
                    lastNearDistance = distance
                    nearX = x
                    nearY = y
                }
            }
    
            const checkHorizontal = (y) => {
                const x = ((y - player_y.value) * vx) / vy + player_x.value
                checkIntersection(x, y, 0, vy)
            }

            const checkVertical = (x) => {
                const y = ((x - player_x.value) * vy) / vx + player_y.value
                checkIntersection(x, y, vx, 0)
            }

            gameContext.fillStyle = "#0000ff"

            // (x - player_x.value) / vx = (y - player_y.value) / vy
            // 
            // for horizontal lines, we know y (y = 1, y = 2 ...)
            if (vy < 0){ // we are lookint top
                const yStart = Math.floor(player_y.value)
                for (let y = yStart; y > yStart - MAP_MAX_LINES_INTERSECT_FIND; y--){
                    checkHorizontal(y)
                }
            } else { // we are lookint bottom
                const yStart = Math.ceil(player_y.value)
                for (let y = yStart; y < yStart + MAP_MAX_LINES_INTERSECT_FIND; y++){
                    checkHorizontal(y)
                }
            }
            
            // for vertical lines, we know x (x = 1, x = 2 ...)
            if (vx > 0){ // we are looking right
                const xStart = Math.ceil(player_x.value)
                for (let x = xStart; x < xStart + MAP_MAX_LINES_INTERSECT_FIND; x++){
                    checkVertical(x)
                }
            } else { // we are looking left
                const xStart = Math.floor(player_x.value)
                for (let x = xStart; x > xStart - MAP_MAX_LINES_INTERSECT_FIND; x--){
                    checkVertical(x)
                }
            }

            if (nearX !== null && nearY !== null){
                drawIntersectionDot(nearX, nearY)
            }
        }

        function drawMap(){
            drawCells()
            drawPlayer()
            drawIntersections()
        }

        let lastFrame = performance.now()
        function animate(){
            const now = performance.now()
            const deltaTime = ((now - lastFrame) / 1000).toFixed(4)
            // console.log('deltaTime', deltaTime, player_x.value, player_y.value)
            update(deltaTime, playerAngleView, w, a, s, d)
            render()
            lastFrame = now

            const bufferArray = new Uint8ClampedArray(frame.buffer, 0, bufferSize)
            const image = new ImageData(bufferArray, GAME_WIDTH, GAME_HEIGHT)
            gameContext.putImageData(image, 0, 0)

            drawMap()

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
            playerAngleView = 2 * Math.PI * (-e.clientX / 600)
        })
    }
}

loadGame()
