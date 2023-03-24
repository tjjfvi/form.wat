import { assertEquals, assertThrows } from "https://deno.land/std@0.181.0/testing/asserts.ts"
import { createFromInstance } from "https://deno.land/x/dprint@0.2.0/mod.ts"

const wasmModule = new WebAssembly.Module(
  await Deno.readFile("./form.wasm"),
)
const wasmInstance = new WebAssembly.Instance(
  wasmModule,
  {
    log: {
      u32: (x: number) => console.log(x),
      str: (start: number, end: number) => {
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
const formatter = createFromInstance(wasmInstance)

const source = await Deno.readTextFile("form.wat")

Deno.test("formats", () => {
  assertFormats(
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
)  `,
    String.raw`(module
  (a b ;; x
    w " x \"  y \\" z
    w ""
    "" z
    ""
    "a\nb"
    c (d
      e ;; y
    ) f
    f (g)
  )
)
`,
  )

  assertFormats(source.replace(/^ */gm, ""), source)
})

Deno.test("errors", () => {
  assertThrows(() => format("("))
  assertThrows(() => format(")"))
  assertThrows(() => format(")("))
  assertThrows(() => format("\""))
  assertThrows(() => format("\"\n\""))
})

function format(text: string) {
  return formatter.formatText("foo.wat", text)
}

function assertFormats(unformatted: string, formatted: string) {
  assertEquals(format(unformatted), formatted)
  assertEquals(format(formatted), formatted)
}
