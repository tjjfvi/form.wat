await Deno.run({ cmd: ["deno", "task", "build"] }).status();

import { createFromInstance } from "https://deno.land/x/dprint@0.2.0/mod.ts";

const wasmModule = new WebAssembly.Module(
  await Deno.readFile("./form.wasm"),
);
const wasmInstance = new WebAssembly.Instance(
  wasmModule,
  {
    log: {
      u32: (x: number) => console.log(x),
      stre: (start: number, end: number) => {
        const data = new Uint8Array(memory.buffer).subarray(start, end);
        try {
          console.log(new TextDecoder().decode(data), data);
        } catch {
          console.log(data);
        }
      },
      brk: () => console.log(),
    },
  },
);
const memory = wasmInstance.exports.memory as WebAssembly.Memory;
const formwat = createFromInstance(wasmInstance);

formwat.setConfig({}, { foo: "bar" });

console.log(formwat.formatText("foo.wat", "(a b;;x\nc(d\ne ;; y\n)f\nf( g ))\n"));
