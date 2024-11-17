import fs from 'node:fs'
import path from 'node:path'
import { createCanvas, ImageData } from 'canvas'

const dir = import.meta.dirname

const spritesRegular = /\(;SPRITES(.*?);\)/s

async function pack(){
    const wat = fs.readFileSync(dir + '/game.wat', { encoding: "utf8" })

    const spritesRegResults = spritesRegular.exec(wat)

    if (!spritesRegResults || !spritesRegResults[1]) return
    
    const spritesString = spritesRegResults[1]
    const sprites = spritesString.trim().split("\n").map(s => s.trim())
    
    let spritesMemoryContent = `
    (memory $sprites 1)
    (data (memory $sprites) (i32.const 0)`

    let spriteFunctins = ""

    let startBytes = 0
    for (let i = 0; i < sprites.length; i++){
        const sprite = sprites[i]
        const spriteName = sprite.replace('.sprt', "")
        const spritePath = path.join(dir, 'sprites', sprite)
        const spriteContent = fs.readFileSync(spritePath, { encoding: "utf8" })
        const bytes = spriteContent.split("\\")
        bytes.shift()
        const width = parseInt(bytes[0], 16)
        const height = parseInt(bytes[1], 16)
        bytes.shift()
        bytes.shift()
        const spriteOnlyPixels = "\\" + bytes.join('\\')

        spritesMemoryContent += `\n        (; ${sprite} ;) "${spriteOnlyPixels}"`

        spriteFunctins += `
        (; ${sprite} ;)
        (func $get_sprite_${spriteName} (result (; $width ;) i32) (result (; $height ;) i32) (result (; $pointer ;) i32)
            i32.const ${width}
            i32.const ${height}
            i32.const ${startBytes}
        )
        `
        
        startBytes += bytes.length
    }

    spritesMemoryContent += '\n    )'

    const newContent = spritesMemoryContent + "\n\n" + spriteFunctins

    const wat_prepared = wat.replace(spritesRegular, newContent)

    fs.writeFileSync(dir + '/game.wat_prepared', wat_prepared)
}

pack()
