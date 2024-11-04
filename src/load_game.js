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

        let newIntersections = []

        function log(number){
            console.log('wasm', number)
        }

        function onIntersectionFound(x, y){
            newIntersections.push({ x, y })
        }

        const exportFunctions = {
            common: { log, onIntersectionFound },
            Math
        }

        // const { instance, module } = await WebAssembly.instantiate(wasmData)
        const { instance, module } = await WebAssembly.instantiateStreaming(fetch('./game.wasm'), exportFunctions)
    
        console.log({ instance, module })

        const { 
            frame, 
            map, map_width, map_height,
            render, update, init, 
            player_x, player_y, player_angle_view,
            FOV 
        } = instance.exports
        
        console.log('memories', frame, map)

        init(GAME_WIDTH, GAME_HEIGHT)

        const bufferSize = GAME_WIDTH * GAME_HEIGHT * 4


        const MAP_SIZE = map_width.value * map_height.value
        const MAP_BUFFER = new Uint8Array(map.buffer, 0, MAP_SIZE)
        const MAP_DRAW_MULTILPLIER = 20
        const MAP_PADDING = 50
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

        function drawPlayer(intersections){
            const px = player_x.value * MAP_DRAW_MULTILPLIER + MAP_PADDING
            const py = player_y.value * MAP_DRAW_MULTILPLIER + MAP_PADDING

            // draw player dot
            gameContext.fillStyle = "#00ff00"
            gameContext.strokeStyle = "#000000"
            gameContext.beginPath()
            gameContext.arc(px, py, 5, 0, Math.PI * 2, true)
            gameContext.fill()
            gameContext.stroke()

            // draw view cone
            gameContext.fillStyle = "#ff000050"
            gameContext.beginPath()
            gameContext.moveTo(px, py)
            for (let i = 0; i < intersections.length; i++){
                const intersetion = intersections[i]
                gameContext.lineTo(intersetion.x * MAP_DRAW_MULTILPLIER + MAP_PADDING, intersetion.y * MAP_DRAW_MULTILPLIER + MAP_PADDING)
            }
            gameContext.lineTo(px, py)
            gameContext.fill()

            // draw center view line
            gameContext.strokeStyle = "#00000090"
            const centerLineX = Math.sin(player_angle_view.value) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + px
            const centerLineY = Math.cos(player_angle_view.value) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + py
            gameContext.beginPath()
            gameContext.moveTo(px, py)
            gameContext.lineTo(centerLineX, centerLineY)
            gameContext.stroke()
        }

        function drawIntersectionDot(x, y){
            gameContext.beginPath()
            gameContext.arc(x * MAP_DRAW_MULTILPLIER + MAP_PADDING, y * MAP_DRAW_MULTILPLIER + MAP_PADDING, 1, 0, Math.PI * 2, true)
            gameContext.fill()
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
            
            const checkCellX = Math.floor(x + vx / 2)
            const checkCellY = Math.floor(y + vy / 2)

            let isWall = false
            const isCellXInRange = checkCellX >= 0 && checkCellX < map_width.value
            const isCellYInRange = checkCellY >= 0 && checkCellY < map_height.value
            
            if (isCellXInRange && isCellYInRange){
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

        const checkHorizontal = (y, vx, vy) => {
            const x = ((y - player_y.value) * vx) / vy + player_x.value
            checkIntersection(x, y, 0, vy)
        }

        const checkVertical = (x, vx, vy) => {
            const y = ((x - player_x.value) * vy) / vx + player_y.value
            checkIntersection(x, y, vx, 0)
        }


        function getIntersectionForAngle(angle){
            const vx = Math.sin(angle)
            const vy = Math.cos(angle)

            lastNearDistance = Infinity
            nearX = null
            nearY = null
            
            gameContext.fillStyle = "#0000ff"

            // (x - player_x.value) / vx = (y - player_y.value) / vy
            // 
            // for horizontal lines, we know y (y = 1, y = 2 ...)
            if (vy < 0){ // we are lookint top
                const yStart = Math.floor(player_y.value)
                for (let y = yStart; y > yStart - MAP_MAX_LINES_INTERSECT_FIND; y--){
                    checkHorizontal(y, vx, vy)
                }
            } else { // we are lookint bottom
                const yStart = Math.ceil(player_y.value)
                for (let y = yStart; y < yStart + MAP_MAX_LINES_INTERSECT_FIND; y++){
                    checkHorizontal(y, vx, vy)
                }
            }
            
            // for vertical lines, we know x (x = 1, x = 2 ...)
            if (vx > 0){ // we are looking right
                const xStart = Math.ceil(player_x.value)
                for (let x = xStart; x < xStart + MAP_MAX_LINES_INTERSECT_FIND; x++){
                    checkVertical(x, vx, vy)
                }
            } else { // we are looking left
                const xStart = Math.floor(player_x.value)
                for (let x = xStart; x > xStart - MAP_MAX_LINES_INTERSECT_FIND; x--){
                    checkVertical(x, vx, vy)
                }
            }

            if (nearX !== null && nearY !== null){
                return { x: nearX, y: nearY }
            }

            return null
        }

        function drawIntersections(intersections){
            gameContext.fillStyle = "#0000ff"
            for (let i = 0; i < intersections.length; i++){
                const intersetion = intersections[i]
                drawIntersectionDot(intersetion.x, intersetion.y)
            }
        }

        function drawMap(){
            const intersections = []
            // console.log(newIntersections)

            // const halfFOV = FOV.value / 2
            // const fovLeft = player_angle_view.value - halfFOV
            // const fovRight = player_angle_view.value + halfFOV
            // for (let angle = fovLeft; angle < fovRight; angle += 0.01){
                // const intersection = getIntersectionForAngle(angle)
                // if (intersection) intersections.push(intersection)
            // }

            drawCells()
            drawPlayer(newIntersections)
            drawIntersections(newIntersections)

            newIntersections = []
        }

        let lastFrame = performance.now()
        let playerAngleView = player_angle_view.value
        let w = 0, a = 0, s = 0, d = 0
        let isDrawMap = true
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

            if (isDrawMap) drawMap()

            requestAnimationFrame(animate)
        }

        requestAnimationFrame(animate)

        body.addEventListener('keydown', (e) => { 
            if (e.key === 'w') w = 1
            if (e.key === 'a') a = 1
            if (e.key === 's') s = 1
            if (e.key === 'd') d = 1
            if (e.key === 'm') isDrawMap = !isDrawMap
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
