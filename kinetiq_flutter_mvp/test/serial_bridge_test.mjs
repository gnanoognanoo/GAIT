import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';

test('serial bridge frames chunks, bounds invalid input and releases a selected port',async()=>{
  const chunks=['LO','W\r\nHIGH\n','x'.repeat(1100),'\nLOW MOTION\n','incomplete'];
  let opened,closed=false,released=false;
  const port={
    open:async opts=>{opened=opts.baudRate;},close:async()=>{closed=true;},
    readable:{getReader:()=>({read:async()=>chunks.length?{value:new TextEncoder().encode(chunks.shift()),done:false}:{done:true},releaseLock:()=>{released=true;}})}
  };
  const window={};
  runInNewContext(await readFile(new URL('../web/device.js',import.meta.url),'utf8'),{window,navigator:{serial:{requestPort:async()=>port}},TextDecoder});
  const lines=[];
  await new Promise((done,reject)=>window.kinetiqOpenSerial(115200,line=>lines.push(line),done).catch(reject));
  assert.deepEqual(lines,['LOW\r','HIGH','','LOW MOTION']);
  assert.equal(opened,115200);assert.ok(closed&&released);
});

