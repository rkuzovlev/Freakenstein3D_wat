import fs from 'node:fs'
import path from 'node:path'
import { createCanvas, ImageData } from 'canvas'

const dir = import.meta.dirname

const spritesRegular = /\(;SPRITES(.*);\)/s

async function pack(){
    const wat = fs.readFileSync(dir + '/game.wat', { encoding: "utf8" })

    const spritesRegResults = spritesRegular.exec(wat)

    if (!spritesRegResults || !spritesRegResults[1]) return
    
    const spritesString = spritesRegResults[1]
    const sprites = spritesString.trim().split("\n").map(s => s.trim())
    
    let spritesMemoryContent = `
    (memory $sprites 1)
    (data (memory $sprites) (i32.const 0)`

    let startBytes = 0
    for (let i = 0; i < sprites.length; i++){
        const sprite = sprites[i]
        const spritePath = path.join(dir, 'sprites', sprite)
        const spriteContent = fs.readFileSync(spritePath, { encoding: "utf8" })
        const bytesCount = spriteContent.split("\\").length - 1

        spritesMemoryContent += `\n        (; ${sprite} ;) "${spriteContent}"`

        startBytes += bytesCount
    }

    spritesMemoryContent += '\n    )'

    const wat_prepared = wat.replace(spritesRegular, spritesMemoryContent)

    fs.writeFileSync(dir + '/game.wat_prepared', wat_prepared)
}

pack()
