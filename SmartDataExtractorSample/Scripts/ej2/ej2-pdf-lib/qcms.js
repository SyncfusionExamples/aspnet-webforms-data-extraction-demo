/* THIS FILE IS GENERATED - DO NOT EDIT */
var QcmsModule = (() => {

  return function (QcmsModule = {}) {
    var Module = typeof QcmsModule != "undefined" ? QcmsModule : {};

    // Environment detection
    var ENVIRONMENT_IS_WEB = typeof window == "object";
    var ENVIRONMENT_IS_WORKER = typeof WorkerGlobalScope != "undefined";
    var ENVIRONMENT_IS_NODE = typeof process == "object" && process.versions && process.versions.node && process.type != "renderer";

    var out = console.log.bind(console);
    var err = console.error.bind(console);

    var ABORT = false;
    var EXITSTATUS = 0;

    // Script directory resolution
    var _scriptName = typeof document != "undefined" ? (document.currentScript && document.currentScript.src) : undefined;
    if (typeof __filename != "undefined") {
      _scriptName = __filename;
    } else if (ENVIRONMENT_IS_WORKER) {
      _scriptName = self.location.href;
    }
    var scriptDirectory = "";
    function locateFile(path) {
      if (Module["locateFile"]) {
        return Module["locateFile"](path, scriptDirectory);
      }
      return scriptDirectory + path;
    }
    if (ENVIRONMENT_IS_WEB || ENVIRONMENT_IS_WORKER) {
      try {
        scriptDirectory = new URL(".", _scriptName).href;
      } catch (e) {
        // noop, fallback keeps empty scriptDirectory
      }
    }

    // Ready promise
    var readyPromiseResolve, readyPromiseReject;
    Module["ready"] = new Promise((resolve, reject) => {
      readyPromiseResolve = resolve;
      readyPromiseReject = reject;
    });

    // wasm state
    var wasmExports;
    var wasmMemory;
    var HEAPU8;
    var runtimeInitialized = false;

    // Helpers
    function updateMemoryViews() {
      var b = wasmMemory.buffer;
      HEAPU8 = new Uint8Array(b);
    }

    function abort(what) {
      Module["onAbort"]?.(what);
      what = "Aborted(" + what + ")";
      err(what);
      ABORT = true;
      var e = new WebAssembly.RuntimeError(what);
      readyPromiseReject(e);
      throw e;
    }

    // Fetch/instantiate helpers
    var dataURIPrefix = "data:application/octet-stream;base64,";
    function isDataURI(filename) {
      return filename && filename.startsWith(dataURIPrefix);
    }

    var wasmBinaryFile;
    function findWasmBinary() {
      // Prefer Module.url, then fallback to default name in local folder
      var file;
      if (Module && Module.url) {
        file = Module.url.replace(/\/+$/, "") + "/qcms_bg.wasm";
      } else {
        file = "qcms_bg.wasm";
      }
      if (!isDataURI(file)) {
        file = locateFile(file);
      }
      return file;
    }

    async function instantiateArrayBuffer(binaryFile, imports) {
      try {
        const resp = await fetch(binaryFile, { credentials: "same-origin" });
        if (!resp.ok) throw new Error(resp.status + " : " + resp.url);
        const buf = await resp.arrayBuffer();
        const result = await WebAssembly.instantiate(buf, imports);
        if (result && result.instance) return result;
        // Older browsers may return instance only
        return { instance: result };
      } catch (reason) {
        err(`failed to asynchronously prepare wasm: ${reason}`);
        abort(reason);
      }
    }

    async function instantiateAsync(binary, binaryFile, imports) {
      if (!binary && typeof WebAssembly.instantiateStreaming == "function" && !isDataURI(binaryFile)) {
        try {
          const response = fetch(binaryFile, { credentials: "same-origin" });
          const instantiationResult = await WebAssembly.instantiateStreaming(response, imports);
          return instantiationResult;
        } catch (reason) {
          err(`wasm streaming compile failed: ${reason}`);
          err("falling back to ArrayBuffer instantiation");
        }
      }
      return instantiateArrayBuffer(binaryFile, imports);
    }

    // The wasm-bindgen import layer expected by the generated qcms.wasm
    // We route to Module.copy_result / Module.copy_rgb if present,
    // else to globalThis.QcmsUtils.{copy_result, copy_rgb}, else throw.
    function getQcmsHelper(name) {
      const local = Module && Module[name];
      if (typeof local === "function") return local;
      const utils = (typeof globalThis !== "undefined" ? globalThis.QcmsUtils : undefined);
      if (utils && typeof utils[name] === "function") return utils[name];
      throw new Error(`QCMS: Missing helper function '${name}'. Provide Module.${name} or global QcmsUtils.${name}.`);
    }

    function getWasmImports() {
      const imports = {};
      imports.wbg = {};

      // These import names must match the exact mangled identifiers produced by wasm-bindgen for your build.
      // They were taken from your current ESM stub.
      imports.wbg.__wbg_copyresult_b08ee7d273f295dd = function (arg0, arg1) {
        // copy_result(ptr, len)
        const fn = getQcmsHelper("copy_result");
        fn(arg0 >>> 0, arg1 >>> 0);
      };
      imports.wbg.__wbg_copyrgb_d60ce17bb05d9b67 = function (arg0) {
        // copy_rgb(len)
        const fn = getQcmsHelper("copy_rgb");
        fn(arg0 >>> 0);
      };

      // wasm-bindgen externref table init
      imports.wbg.__wbindgen_init_externref_table = function () {
        const table = wasmExports.__wbindgen_export_0;
        const offset = table.grow(4);
        table.set(0, undefined);
        table.set(offset + 0, undefined);
        table.set(offset + 1, null);
        table.set(offset + 2, true);
        table.set(offset + 3, false);
      };

      // Error propagation from Rust to JS
      imports.wbg.__wbindgen_throw = function (arg0, arg1) {
        // Read UTF-8 from wasm memory; minimal, only for errors
        const start = arg0 >>> 0;
        const len = arg1 >>> 0;
        const end = start + len;
        const slice = HEAPU8.subarray(start, end);
        let str;
        if (typeof TextDecoder !== "undefined") {
          str = new TextDecoder("utf-8").decode(slice);
        } else {
          // Fallback: naive decoding
          str = Array.from(slice).map(c => String.fromCharCode(c)).join("");
        }
        throw new Error(str);
      };

      return imports;
    }

    // QCMS public API enums (must match your ESM definitions)
    const DataType = {
      RGB8: 0,
      RGBA8: 1,
      BGRA8: 2,
      Gray8: 3,
      GrayA8: 4,
      CMYK: 5
    };
    const Intent = {
      Perceptual: 0,
      RelativeColorimetric: 1,
      Saturation: 2,
      AbsoluteColorimetric: 3
    };
    Module.DataType = DataType;
    Module.Intent = Intent;

    function initRuntime() {
      runtimeInitialized = true;
      // wasm-bindgen start (constructor-like)
      if (wasmExports && typeof wasmExports.__wbindgen_start === "function") {
        wasmExports.__wbindgen_start();
      }
    }

    async function createWasm() {
      function receiveInstance(instance) {
        wasmExports = instance.exports;
        // Memory is exported as 'memory' by wasm-bindgen
        wasmMemory = wasmExports.memory;
        updateMemoryViews();
        return wasmExports;
      }

      const imports = getWasmImports();
      wasmBinaryFile ??= findWasmBinary();

      try {
        const result = await instantiateAsync(null, wasmBinaryFile, imports);
        const instance = result.instance || result; // compat
        return receiveInstance(instance);
      } catch (e) {
        readyPromiseReject(e);
        return Promise.reject(e);
      }
    }
let WASM_VECTOR_LEN = 0;

    // Wrap wasm exports with friendlier JS functions
    function exposeApi() {
      // For array passing we need a malloc; wasm-bindgen exports __wbindgen_malloc
      const malloc = wasmExports.__wbindgen_malloc;
function passArray8ToWasm0(arg) {
    const len = arg.length >>> 0;
    const ptr = (malloc(len, 1) >>> 0);
    getUint8ArrayMemory0().set(arg, ptr / 1);
    WASM_VECTOR_LEN = arg.length;
    return ptr;
}
let cachedUint8ArrayMemory0 = null;
function getUint8ArrayMemory0() {
    if (cachedUint8ArrayMemory0 === null || cachedUint8ArrayMemory0.byteLength === 0) {
        cachedUint8ArrayMemory0 = new Uint8Array(wasmExports.memory.buffer);
    }
    return cachedUint8ArrayMemory0;
}
      Module.qcms_convert_array = function (transformer, src) {
        const ptr = passArray8ToWasm0(src);
        const len = WASM_VECTOR_LEN;
        wasmExports.qcms_convert_array(transformer, ptr, len);
      };
      Module.qcms_convert_one = function (transformer, src) {
        wasmExports.qcms_convert_one(transformer >>> 0, src >>> 0);
      };
      Module.qcms_convert_three = function (transformer, src1, src2, src3) {
        wasmExports.qcms_convert_three(transformer >>> 0, src1 >>> 0, src2 >>> 0, src3 >>> 0);
      };
      Module.qcms_convert_four = function (transformer, src1, src2, src3, src4) {
        wasmExports.qcms_convert_four(transformer , src1 , src2 , src3 , src4 );
      };
      Module.memory = wasmExports.memory;
      Module.qcms_transformer_from_memory = function (mem, in_type, intent) {
        const ptr = passArray8ToWasm0(mem);
        const len = WASM_VECTOR_LEN
        const ret = wasmExports.qcms_transformer_from_memory(ptr >>> 0, len >>> 0, in_type >>> 0, intent >>> 0);
        return ret >>> 0;
      };
      Module.qcms_drop_transformer = function (transformer) {
        wasmExports.qcms_drop_transformer(transformer >>> 0);
      };
    }

    // Boot
    (async () => {
      try {
        await createWasm();
        initRuntime();
        exposeApi();
        // Let user hook
        Module["onRuntimeInitialized"]?.();
        readyPromiseResolve(Module);
      } catch (e) {
        // already rejected by createWasm or abort
      }
    })();

    return Module;
  };

})();

// UMD export
if (typeof exports === 'object' && typeof module === 'object')
  module.exports = QcmsModule;
else if (typeof define === 'function' && define['amd'])
  define([], function () {
    return QcmsModule;
  });
else if (typeof exports === 'object')
  exports["QcmsModule"] = QcmsModule;