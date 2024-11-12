const canvas = document.getElementById('canvas')
const body = document.body
const widthInput = document.getElementById('width')
const heightInput = document.getElementById('height')
const savePaletteButton = document.getElementById('save_palette')
const loadPaletteButton = document.getElementById('load_palette')
const paletteSaveInfo = document.getElementById('palette_save_info')

const saveCanvasButton = document.getElementById('save_canvas')
const loadCanvasButton = document.getElementById('load_canvas')
const canvasSaveInfo = document.getElementById('canvas_save_info')

const context = canvas.getContext('2d')
const cellSize = 30

let width = 10
let height = 10
let imageColors = []
let selectedColor = 0
let isDrawing = false

const colors = Array(15)
    .fill(0)
    .map((_, i) => document.getElementById(`color_${i}`))

colors.forEach(color => {
    const colorNumber = parseInt(color.id.split('_')[1], 10)
    const colorPreview = window[`color_preview_${colorNumber}`]
    const colorSelect = window[`color_select_${colorNumber}`]
    setColorForPreview(colorNumber, color.value)
    
    color.addEventListener('change', () => {
        setColorForPreview(colorNumber, color.value)
        colorSelect.checked = true
        selectedColor = colorNumber
        updateCanvas()
    })
})

function setColorForPreview(colorId, color){
    const colorPreview = window[`color_preview_${colorId}`]
    colorPreview.style.backgroundColor = color
}

const colorSelects = Array(15)
    .fill(0)
    .map((_, i) => document.getElementById(`color_select_${i}`))

colorSelects.forEach(colorSelect => {
    colorSelect.addEventListener('change', () => {
        selectedColor = parseInt(colorSelect.id.split('_')[2], 10)
    })
})

const transparentColor = document.getElementById(`color_select_transparent`)
transparentColor.addEventListener('change', () => selectedColor = 15)

updateDimensions()
updateCanvas()

widthInput.addEventListener('change', function(){
    let value = parseInt(this.value, 10)
    
    if (!Number.isInteger(value) || value < 1) value = width

    width = value
    updateDimensions()
    updateCanvas()
})

heightInput.addEventListener('change', function(){
    let value = parseInt(this.value, 10)
    
    if (!Number.isInteger(value) || value < 1) value = height

    height = value
    updateDimensions()
    updateCanvas()
})

savePaletteButton.addEventListener('click', function(){
    let palette = ""
    colors.forEach(colorInput => {
        const color = colorInput.value.substring(1)
        const b1 = color.substring(0, 2)
        const b2 = color.substring(2, 4)
        const b3 = color.substring(4)
        palette += `\\${b1}\\${b2}\\${b3}`
    })
    paletteSaveInfo.style.display = "block"
    paletteSaveInfo.textContent = palette
})

loadPaletteButton.addEventListener('click', function(){
    const palette = prompt('insert palette wasm hex binary string')
    const paletteBytes = palette.split('\\')
    paletteBytes.shift()

    const colorsCount = paletteBytes.length / 3
    for (let i = 0; i < colorsCount; i++){
        const color = "#" + paletteBytes[i * 3].toString() + paletteBytes[i * 3 + 1].toString() + paletteBytes[i * 3 + 2].toString()
        setColorForPreview(i, color)
        colors[i].value = color
    }
})

saveCanvasButton.addEventListener('click', function(){
    let canvasBytes = "\\" + height.toString(16) + "\\" + width.toString(16)
    let lastByte = 0
    let odd

    for (let y = 0; y < height; y++){
        for (let x = 0; x < width; x++){
            odd = (y * width + x) % 2 === 1

            const colorId = imageColors[y][x]
            if (odd) lastByte = lastByte << 4    
            lastByte = lastByte | colorId
            if (odd) {
                canvasBytes += "\\" + lastByte.toString(16)
                lastByte = 0
            }
        }
    }

    if (!odd) {
        lastByte = lastByte << 4
        canvasBytes += "\\" + lastByte.toString(16)
    }

    canvasSaveInfo.style.display = "block"
    canvasSaveInfo.textContent = canvasBytes
})

loadCanvasButton.addEventListener('click', function(){
    // \3\5\33\3f\ff\ff\ff\ff\ff\f0
    let canvasBytes = prompt('insert canvas wasm hex binary string')

    canvasBytes = canvasBytes.split('\\')
    canvasBytes.shift()

    height = canvasBytes[0]
    width = canvasBytes[1]

    canvasBytes = canvasBytes.slice(2)

    const colors = []
    canvasBytes.forEach(byteString => {
        const byte = parseInt(byteString, 16)
        const color1 = (byte & 0xf0) >> 4
        const color2 = byte & 0xf
        colors.push(color1, color2)
    })

    for (let y = 0; y < height; y++){
        for (let x = 0; x < width; x++){
            imageColors[y][x] = colors.shift()
        }
    }

    updateDimensions()
    updateCanvas()
})

function onCanvasMouseDown(e){
    const x = Math.floor(e.offsetX / cellSize)
    const y = Math.floor(e.offsetY / cellSize)

    renderSelectedColor(x, y)
    imageColors[y][x] = selectedColor
    isDrawing = true
}

function onCanvasMouseMove(e){
    if (isDrawing){
        const x = Math.abs(Math.floor(e.offsetX / cellSize))
        const y = Math.abs(Math.floor(e.offsetY / cellSize))

        renderSelectedColor(x, y)
        imageColors[y][x] = selectedColor
    }
}

function onBodyMouseUp(){
    isDrawing = false
}

canvas.addEventListener('mousedown', onCanvasMouseDown)
canvas.addEventListener('mousemove', onCanvasMouseMove)
body.addEventListener('mouseup', onBodyMouseUp)

function updateDimensions(){
    widthInput.value = width
    heightInput.value = height
    canvas.width = width * cellSize - 3
    canvas.height = height * cellSize - 3

    if (!Array.isArray(imageColors)){
        imageColors = []
    }

    for (let y = 0; y < height; y++){
        if (!Array.isArray(imageColors[y])){
            imageColors[y] = []
        }

        for (let x = 0; x < width; x++){
            const cell = imageColors[y][x]
            
            if (!Number.isInteger(cell) || cell < 0 || cell > 15){
                imageColors[y][x] = 15
            }
        }
    }
}

function updateCanvas(){
    for (let y = 0; y < height; y++){
        for (let x = 0; x < width; x++){
            const colorId = imageColors[y][x]

            if (colorId === 15){
                renderTransparent(x, y)
            } else {
                const color = colors[colorId].value
                renderColor(x, y, color)
            }
        }
    }
}

function renderSelectedColor(x, y){
    if (selectedColor === 15){
        renderTransparent(x, y)
    } else {
        const color = colors[selectedColor].value
        renderColor(x, y, color)
    }
}

function renderTransparent(x, y){
    context.strokeStyle = "#606060"
    context.fillStyle = "#ffffff"
    context.beginPath()
    context.rect(x * cellSize, y * cellSize, cellSize, cellSize)
    context.fill()
    context.stroke()

    context.fillStyle = "#00000020"
    context.beginPath()
    context.rect(x * cellSize, y * cellSize, cellSize / 2, cellSize / 2)
    context.rect(
        x * cellSize + cellSize / 2,
        y * cellSize + cellSize / 2,
        cellSize / 2,
        cellSize / 2
    )
    context.fill()
}

function renderColor(x, y, color){
    context.strokeStyle = "#606060"
    context.fillStyle = color
    context.beginPath()
    context.rect(x * cellSize, y * cellSize, cellSize, cellSize)
    context.fill()
    context.stroke()
}
