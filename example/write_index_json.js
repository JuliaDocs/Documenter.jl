var fs = require('fs')
var src = process.argv[2]
var dst = process.argv[3]
console.log(`Converting: ${src}`)
eval(fs.readFileSync(src)+'');
var json_index = JSON.stringify(documenterSearchIndex, null, 2)
fs.writeFile(dst, json_index, (err) => {
    if(err) throw err;
    console.log(`Written: ${dst}`)
})
