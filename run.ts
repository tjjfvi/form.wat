await Deno.run({ cmd: ["deno", "task", "build"] }).status()

import { createFromInstance } from "https://deno.land/x/dprint@0.2.0/mod.ts"

const wasmModule = new WebAssembly.Module(
  await Deno.readFile("./form.wasm"),
)
const wasmInstance = new WebAssembly.Instance(
  wasmModule,
  {
    log: {
      u32: (x: number) => console.log(x),
      stre: (start: number, end: number) => {
        const data = new Uint8Array(memory.buffer).subarray(start, end)
        try {
          console.log(new TextDecoder().decode(data), data)
        } catch {
          console.log(data)
        }
      },
      brk: () => console.log(),
    },
  },
)
const memory = wasmInstance.exports.memory as WebAssembly.Memory
const formwat = createFromInstance(wasmInstance)

formwat.setConfig({}, { foo: "bar" })

console.log(formwat.formatText(
  "foo.wat",
  String.raw`(module
(a b;;x
w" x \"  y \\"z
w""
""z
""
"a\nb"
c(d
e ;; y
)f
f( g ))
)
`,
))

import { assertEquals } from "https://deno.land/std@0.181.0/testing/asserts.ts"
const source = await Deno.readTextFile("form.wat")
assertEquals(formwat.formatText("foo.wat", source), source)
