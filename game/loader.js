async function prepareWasm() {
    const img = window.i
    img.style.display = "none"

    const width = img.width
    const height = img.height

    const canvas = new OffscreenCanvas(width, height)
    const context = canvas.getContext('2d')
    
    context.drawImage(img, 0, 0)

    const imgData = context.getImageData(0, 0, width, height)
    
    const imgDataView = new DataView(imgData.data.buffer)
    const bodyLength = imgDataView.getUint16(0)
    const wasmLength = imgDataView.getUint16(4)

    const componentsCount = Math.ceil(bodyLength / 4)
    const components = []

    const wasmDataWithAlpha = imgData.data.buffer.slice(8, bodyLength + 8)
    for (let i = 0; i < componentsCount; ++i){
        components.push(wasmDataWithAlpha.slice(i*4, i*4+3))
    }

    const componentsBlob = new Blob(components)
    const wasmDataBuffer = await componentsBlob.arrayBuffer()
    const wasmData = wasmDataBuffer.slice(0, wasmLength)

    gameInit(wasmData)
}

function loadGame() {
    if (window.i.complete) prepareWasm()
    else window.i.onload = prepareWasm
}

loadGame()
