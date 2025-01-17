const GAME_WIDTH = 800
const GAME_HEIGHT = 600

const gameCanvas = window.game
const gameContext = gameCanvas.getContext('2d')
const body = document.body

gameCanvas.width = GAME_WIDTH
gameCanvas.height = GAME_HEIGHT

async function gameInit(wasmData) {
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

    const { instance } = await WebAssembly.instantiate(wasmData, exportFunctions)
    console.log(instance)

    const {
        frame, palettes,
        objects, objects_intersected,
        map, map_width, map_height,
        render, update, init, 
        player_x, player_y,
        FOV, intersection_map_max_distance_in_lines,
        map_is_drawing
    } = instance.exports

    console.log('memory', { frame, map, objects, objects_intersected, palettes })

    init(GAME_WIDTH, GAME_HEIGHT)

    const bufferSize = GAME_WIDTH * GAME_HEIGHT * 4


    let playerAngleView = Math.PI / 2
    const MAP_SIZE = map_width.value * map_height.value
    const MAP_BUFFER = new Uint8Array(map.buffer, 0, MAP_SIZE)
    const MAP_DRAW_MULTILPLIER = 20
    const MAP_PADDING = 50
    const MAP_MAX_LINES_INTERSECT_FIND = intersection_map_max_distance_in_lines.value
    const BRICK_WALL_CHAR_CODE = "0".charCodeAt(0)
    const ROOM_WALL_CHAR_CODE = "1".charCodeAt(0)
    const GREEN_DOOR_CHAR_CODE = "G".charCodeAt(0)
    const RED_DOOR_CHAR_CODE = "R".charCodeAt(0)
    const BLUE_DOOR_CHAR_CODE = "B".charCodeAt(0)
    const YELLOW_DOOR_CHAR_CODE = "Y".charCodeAt(0)
    const FLOOR_CHAR_CODE = ".".charCodeAt(0)
    const WALLS = [
        BRICK_WALL_CHAR_CODE, 
        ROOM_WALL_CHAR_CODE,
        GREEN_DOOR_CHAR_CODE,
        RED_DOOR_CHAR_CODE,
        BLUE_DOOR_CHAR_CODE,
        YELLOW_DOOR_CHAR_CODE,
    ]

    function drawWallCell(x, y, text){
        gameContext.fill()
        gameContext.fillStyle = "#000000"
        gameContext.fillText(text, x + 0.35 * MAP_DRAW_MULTILPLIER , y + 0.65 * MAP_DRAW_MULTILPLIER)
        gameContext.stroke()
    }

    function drawCell(cellX, cellY, type){
        const x = cellX * MAP_DRAW_MULTILPLIER + MAP_PADDING
        const y = cellY * MAP_DRAW_MULTILPLIER + MAP_PADDING
        
        gameContext.fillStyle = "#ddddddaa"
        gameContext.strokeStyle = "#333333aa"
        gameContext.beginPath()
        gameContext.rect(x, y, MAP_DRAW_MULTILPLIER, MAP_DRAW_MULTILPLIER)
        switch (type) {
            case GREEN_DOOR_CHAR_CODE: drawWallCell(x, y, "G"); break
            case RED_DOOR_CHAR_CODE: drawWallCell(x, y, "R"); break
            case BLUE_DOOR_CHAR_CODE: drawWallCell(x, y, "B"); break
            case YELLOW_DOOR_CHAR_CODE: drawWallCell(x, y, "Y"); break
            case ROOM_WALL_CHAR_CODE: drawWallCell(x, y, "1"); break
            case BRICK_WALL_CHAR_CODE: drawWallCell(x, y, "0"); break

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
        gameContext.strokeStyle = "#ff0000"
        const centerLineX = Math.sin(playerAngleView) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + px
        const centerLineY = Math.cos(playerAngleView) * MAP_DRAW_MULTILPLIER * MAP_MAX_LINES_INTERSECT_FIND + py
        gameContext.beginPath()
        gameContext.moveTo(px, py)
        gameContext.lineTo(centerLineX, centerLineY)
        gameContext.stroke()


        // draw delta vector
        const dx = a - d
        const dy = w - s

        const rotated_x = dx * Math.cos(-playerAngleView) - dy * Math.sin(-playerAngleView)
        const rotated_y = dx * Math.sin(-playerAngleView) + dy * Math.cos(-playerAngleView)

        const on_map_rotated_x = rotated_x * MAP_DRAW_MULTILPLIER + px
        const on_map_rotated_y = rotated_y * MAP_DRAW_MULTILPLIER + py

        gameContext.strokeStyle = "#00ff00"
        gameContext.beginPath()
        gameContext.moveTo(px, py)
        gameContext.lineTo(on_map_rotated_x, on_map_rotated_y)
        gameContext.stroke()
    }

    function drawIntersectionDot(x, y){
        gameContext.beginPath()
        gameContext.arc(x * MAP_DRAW_MULTILPLIER + MAP_PADDING, y * MAP_DRAW_MULTILPLIER + MAP_PADDING, 3, 0, Math.PI * 2, true)
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
            isWall = WALLS.includes(cell)
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

    function drawIntersections(intersections, color){
        gameContext.fillStyle = color
        for (let i = 0; i < intersections.length; i++){
            const intersetion = intersections[i]
            drawIntersectionDot(intersetion.x, intersetion.y)
        }
    }

    function drawMap(){
        const intersections = []
        // console.log(newIntersections)

        // const halfFOV = FOV.value / 2
        // const fovLeft = playerAngleView + halfFOV
        // const fovRight = playerAngleView - halfFOV
        // 
        // for (let angle = fovLeft; angle > fovRight; angle -= 0.01){
        //     const intersection = getIntersectionForAngle(angle)
        //     if (intersection) intersections.push(intersection)
        // }

        // 2 * atan(D/(2*L)) - D размер объекта, L расстояние до объекта
//             const intersection = getIntersectionForAngle(playerAngleView)
//             if (intersection) {
//                 intersections.push(intersection)
//                 const dvx = intersection.x - player_x.value
//                 const dvy = intersection.y - player_y.value
//                 const distance = Math.sqrt(dvx*dvx + dvy*dvy) * 10
//                 const angularDiameter = 2 * Math.atan(3 / (2 * distance))
//                 const eyeAngularDiameter = 1.91986
// 
//                 // console.log(1 - (angularDiameter / eyeAngularDiameter))
//             }
        

        drawCells()
        drawPlayer(newIntersections)
        drawIntersections(newIntersections, "#0000ff")

        newIntersections = []
    }

    
    let isDrawMap = false
    map_is_drawing.value = isDrawMap ? 1 : 0
    
    function mapToggle(){
        isDrawMap = !isDrawMap
        map_is_drawing.value = isDrawMap ? 1 : 0
    }

    let w = 0, a = 0, s = 0, d = 0
    let lastTiming = 0
    function animate(timing){
        const deltaTime = ((timing - lastTiming) / 1000).toFixed(4)
        update(deltaTime, playerAngleView, a-d, w-s)
        render()
        lastTiming = timing

        let bufferArray = new Uint8ClampedArray(frame.buffer, 0, bufferSize)
        let image = new ImageData(bufferArray, GAME_WIDTH, GAME_HEIGHT)
        gameContext.putImageData(image, 0, 0)
        
        if (isDrawMap) drawMap()

        requestAnimationFrame(animate)
    }

    requestAnimationFrame(animate)

    body.addEventListener('keydown', (e) => { 
        if (e.code === 'KeyW') w = 1
        if (e.code === 'KeyA') a = 1
        if (e.code === 'KeyS') s = 1
        if (e.code === 'KeyD') d = 1
        if (e.code === 'KeyM') mapToggle()
        if (e.code === 'Escape') document.exitPointerLock()
    })

    body.addEventListener('keyup', (e) => { 
        if (e.code === 'KeyW') w = 0
        if (e.code === 'KeyA') a = 0
        if (e.code === 'KeyS') s = 0
        if (e.code === 'KeyD') d = 0
    })

    gameCanvas.addEventListener('click', () => {
        gameCanvas.requestPointerLock()
    })

    document.addEventListener("pointerlockchange", lockChangeAlert, false)

    function updatePosition(e){
        playerAngleView -= e.movementX / 500
        playerAngleView -= Math.trunc(playerAngleView / (Math.PI * 2)) * Math.PI * 2
        if (playerAngleView < 0) playerAngleView = Math.PI * 2 - playerAngleView
    }

    function lockChangeAlert() {
        if (document.pointerLockElement === gameCanvas) {
            document.addEventListener("mousemove", updatePosition, false)
        } else {
            document.removeEventListener("mousemove", updatePosition, false)
        }
    }
}