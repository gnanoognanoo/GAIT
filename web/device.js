// Read-only, user-selected serial stream. No device commands are sent.
let activePort, reader, opening = false;
window.kinetiqSerialSupported = !!navigator.serial;
window.kinetiqOpenSerial = async (baud, line, end) => {
  if (opening || activePort) throw new Error('A serial connection is already open or pending.');
  opening = true;
  let port;
  try {
    port = await navigator.serial.requestPort();
    await port.open({baudRate: baud});
    activePort = port;
  } finally { opening = false; }
  reader = port.readable.getReader();
  const localReader = reader;
  const decoder = new TextDecoder();
  (async () => {
    let pending = '', overflow = false;
    try {
      for (;;) {
        const {done, value} = await localReader.read();
        if (done) break;
        for (const ch of decoder.decode(value, {stream:true})) {
          if (ch === '\n') {
            line(overflow ? '' : pending);
            pending = ''; overflow = false;
          } else if (pending.length < 1024) pending += ch;
          else overflow = true;
        }
      }
    } finally {
      localReader.releaseLock();
      try { await port.close(); } finally {
        if (activePort === port) { reader = null; activePort = null; }
        end();
      }
    }
  })().catch(() => {});
};
window.kinetiqCloseSerial = () => { if (reader) reader.cancel().catch(() => {}); };

