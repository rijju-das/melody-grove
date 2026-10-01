const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const source=fs.readFileSync(require.resolve('../docs/voice-input.js'),'utf8');
function harness(){
 let request,activate,calls=0;const events=[],reports=[],errors=[],track={stopped:false,stop(){this.stopped=true;}};
 const sandbox={module:{exports:{}},isSecureContext:true,Float32Array,performance,setTimeout,clearTimeout,setInterval,clearInterval,
  navigator:{mediaDevices:{getUserMedia(){calls++;return new Promise((resolve,reject)=>{request={resolve,reject};});}}},
  AudioContext:class{constructor(){this.state='suspended';}resume(){return new Promise(resolve=>{activate=()=>{this.state='running';resolve();};});}close(){this.state='closed';return Promise.resolve();}}
 };
 vm.runInNewContext(source,sandbox);
 const mic=new sandbox.GroveVoice.VoiceInput({send:(...x)=>events.push(x),report:x=>reports.push(x),allowed:()=>true,onError:x=>errors.push(x)});
 return {mic,track,errors,reports,get calls(){return calls;},grant(){request.resolve({getTracks:()=>[track],getAudioTracks:()=>[track]});},deny(){request.reject(Object.assign(new Error('blocked'),{name:'NotAllowedError'}));},activate(){activate();}};
}
(async()=>{
 let h=harness(),pending=h.mic.start();
 assert.equal(h.calls,1,'Permission requested synchronously without waiting for audio resume');
 h.deny();await pending;
 assert.equal(h.errors[0].code,'NotAllowedError');assert.equal(h.mic.pending,false);
 h=harness();pending=h.mic.start();h.mic.stop();h.grant();await pending;
 assert(h.track.stopped,'Late permission grant must release microphone');assert.equal(h.mic.stream,null);
 h=harness();pending=h.mic.start();h.grant();await new Promise(setImmediate);
 assert(h.mic.stream,'Permission resolved; audio activation is still pending');
 h.mic.stop();assert(h.track.stopped,'Stop releases permission-granted stream while audio activation is pending');
 h.activate();await pending;assert.equal(h.mic.pending,false);assert.equal(h.mic.stream,null);
 console.log('VOICE PERMISSION PASS: immediate prompt request, denial recovery callback, late grant cleanup, cancellation during audio activation');
})().catch(e=>{console.error(e);process.exit(1);});
