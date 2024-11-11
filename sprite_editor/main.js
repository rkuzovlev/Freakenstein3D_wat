const canvas = document.getElementById('canvas')
const body = document.body
const widthInput = document.getElementById('width')
const heightInput = document.getElementById('height')

const context = canvas.getContext('2d')
const cellSize = 30

let width = 10
let height = 10
let imageColors = []
let selectedColor = 0
let isDrawing = false

const colors = Array(16)
    .fill(0)
    .map((_, i) => document.getElementById(`color_${i}`))

colors.forEach(color => {
    const colorNumber = parseInt(color.id.split('_')[1], 10)
    const colorPreview = window[`color_preview_${colorNumber}`]
    const colorSelect = window[`color_select_${colorNumber}`]
    colorPreview.style.backgroundColor = color.value
    
    color.addEventListener('change', () => {
        colorPreview.style.backgroundColor = color.value
        colorSelect.checked = true
        selectedColor = colorNumber
        updateCanvas()
    })
})

const colorSelects = Array(16)
    .fill(0)
    .map((_, i) => document.getElementById(`color_select_${i}`))

colorSelects.forEach(colorSelect => {
    colorSelect.addEventListener('change', () => {
        selectedColor = parseInt(colorSelect.id.split('_')[2], 10)
    })
})

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

function onCanvasMouseDown(e){
    const x = Math.floor(e.offsetX / cellSize)
    const y = Math.floor(e.offsetY / cellSize)

    renderSelectedColor(x, y)
    imageColors[y][x] = selectedColor
    isDrawing = true
}

function onCanvasMouseMove(e){
    if (isDrawing){
        const x = Math.floor(e.offsetX / cellSize)
        const y = Math.floor(e.offsetY / cellSize)
    
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
    canvas.width = width * cellSize
    canvas.height = height * cellSize

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
                imageColors[y][x] = 0
            }
        }
    }
}

function updateCanvas(){
    for (let y = 0; y < height; y++){
        for (let x = 0; x < width; x++){
            const colorId = imageColors[y][x]

            if (colorId === 0){
                renderTransparent(x, y)
            } else {
                const color = colors[colorId].value
                renderColor(x, y, color)
            }
        }
    }
}

function renderSelectedColor(x, y){
    if (selectedColor === 0){
        renderTransparent(x, y)
    } else {
        const color = colors[selectedColor].value
        renderColor(x, y, color)
    }
}

function renderTransparent(x, y){
    context.fillStyle = "#ffffff"
    context.beginPath()
    context.rect(x * cellSize, y * cellSize, cellSize, cellSize)
    context.fill()

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
    context.fillStyle = color
    context.beginPath()
    context.rect(x * cellSize, y * cellSize, cellSize, cellSize)
    context.fill()
}
