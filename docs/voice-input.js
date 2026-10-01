/* Local pitch analysis only. No recording, storage, network or speech service. */
(function(root){
  'use strict';
  function detectPitch(input, rate, floor=0.002) {
    const stride=Math.max(1,Math.floor(rate/8000)), size=Math.floor(input.length/stride);
    const data=new Float32Array(size);let rms=0,mean=0;
    for(let i=0;i<size;i++){data[i]=input[i*stride];mean+=data[i];}
    mean/=size;
    for(let i=0;i<size;i++){data[i]-=mean;rms+=data[i]*data[i];}
    rms=Math.sqrt(rms/size);
    if(rms<floor)return {hz:0,rms};
    const sampleRate=rate/stride, half=Math.floor(size/2);
    const maxLag=Math.min(Math.floor(sampleRate/75),half-1), minLag=Math.max(2,Math.floor(sampleRate/1000));
    const difference=new Float32Array(maxLag+1);let sum=0;
    for(let lag=1;lag<=maxLag;lag++){
      let d=0;for(let i=0;i<half;i++){const v=data[i]-data[i+lag];d+=v*v;}
      sum+=d;difference[lag]=sum>1e-9?d*lag/sum:1;
    }
    for(let lag=minLag;lag<maxLag-1;lag++){
      const a=difference[lag-1],b=difference[lag],c=difference[lag+1];
      if(b<0.15&&b<=a&&b<=c){const den=a-2*b+c;return {hz:sampleRate/(lag+(Math.abs(den)>1e-9?(a-c)/(2*den):0)),rms};}
    }
    return {hz:0,rms};
  }
  class VoiceInput {
    constructor({send,report,allowed,onError=()=>{}}){Object.assign(this,{send,report,allowed,onError});this.serial=0;this.stream=null;this.context=null;this.timer=null;this.pending=false;this.mode='off';this.listening=false;}
    async start(){
      this.stop();
      if(!this.allowed()){this.report('Resume Stage 4 before enabling the microphone.');return;}
      const token=++this.serial;this.pending=true;this.mode='permission';this.report('Allow microphone access to start the check.');
      let context,stream,resumeTimer;
      try{
        if(!root.isSecureContext||!navigator.mediaDevices?.getUserMedia)throw new Error('unsupported');
        context=new (root.AudioContext||root.webkitAudioContext)();this.context=context;
        // Start permission from the tap, without waiting for audio activation first.
        const resumed=context.resume().catch(error=>error);
        try{if(navigator.audioSession)navigator.audioSession.type='play-and-record';}catch{}
        stream=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:true,noiseSuppression:false,autoGainControl:false},video:false});
        if(token!==this.serial||!this.allowed()){stream.getTracks().forEach(t=>t.stop());await context.close().catch(()=>{});if(token===this.serial)this.stop();return;}
        this.stream=stream; // Stop/pagehide must release tracks even while audio activation is pending.
        const resumeError=await Promise.race([resumed,new Promise((_,reject)=>{resumeTimer=setTimeout(()=>reject(new Error('audio-start')),4000);})]);
        clearTimeout(resumeTimer);
        if(resumeError)throw resumeError;
        if(token!==this.serial||!this.allowed()){stream.getTracks().forEach(t=>t.stop());await context.close().catch(()=>{});if(token===this.serial)this.stop();return;}
        this.stream=stream;this.pending=false;this.mode='calibrating';
        const source=context.createMediaStreamSource(stream),analyser=context.createAnalyser();
        analyser.fftSize=4096;source.connect(analyser); // Deliberately never connected to speakers.
        const buffer=new Float32Array(analyser.fftSize),noise=[];
        const began=performance.now();let floor=0.002;
        stream.getAudioTracks().forEach(t=>t.onended=()=>{if(token===this.serial){this.stop();this.report('Microphone disconnected. Reconnect it and tap Enable microphone.');}});
        context.onstatechange=()=>{if(token===this.serial&&context.state!=='running'&&this.mode==='ready'){this.stop();this.report('Microphone interrupted. Tap Enable microphone to resume.');}};
        this.report('Microphone check · stay quiet for a moment…');
        this.timer=setInterval(()=>{
          if(token!==this.serial)return;
          if(!this.allowed()){this.stop();return;}
          analyser.getFloatTimeDomainData(buffer);
          if(this.mode==='calibrating'){
            const result=detectPitch(buffer,context.sampleRate,2);noise.push(result.rms);
            if(performance.now()-began>=1500){
              noise.sort((a,b)=>a-b);floor=Math.max(0.002,noise[Math.floor(noise.length*.25)]*1.8);
              if(floor>0.035){this.stop();this.report('The room is quite noisy. Move somewhere quieter, then try again.');return;}
              this.mode='ready';this.send('mic_on');this.report('Microphone ready · tap Listen, then sing or hum.');
            }
            return;
          }
          if(this.listening){
            const muted=stream.getAudioTracks().some(t=>t.muted);
            const detected=detectPitch(buffer,context.sampleRate,floor);
            this.send('voice_level',muted?0:detected.rms);
            this.send('pitch',muted?0:detected.hz);
          }
        },80);
      }catch(error){
        clearTimeout(resumeTimer);
        if(stream)stream.getTracks().forEach(t=>t.stop());
        if(context&&context.state!=='closed')context.close().catch(()=>{});
        if(token!==this.serial)return;
        this.stop();
        const text=error.name==='NotAllowedError'?'Microphone access was not allowed. Enable it in your browser’s website settings, then try again.':error.name==='NotFoundError'?'No microphone was found. Connect one, or use listening practice.':error.name==='NotReadableError'?'The microphone is busy. Close other apps using it, then try again.':error.message==='unsupported'?'Microphone access needs a supported browser on HTTPS. Open the game in Safari or Chrome.':'Could not start the microphone. Try again, or use listening practice.';
        this.report(text);
        this.onError({code:error.message==='unsupported'?'unsupported':error.name||'unknown'});
      }
    }
    setListening(value){
      this.listening=value;
      // The track stays allocated between notes, but receives silence during playback.
      if(this.mode==='ready'&&this.stream)this.stream.getAudioTracks().forEach(t=>t.enabled=value);
    }
    stop(){
      const wasActive=this.mode!=='off';
      ++this.serial;clearInterval(this.timer);this.timer=null;this.pending=false;this.mode='off';this.listening=false;
      if(this.stream)this.stream.getTracks().forEach(t=>t.stop());this.stream=null;
      if(this.context){this.context.onstatechange=null;this.context.close().catch(()=>{});}this.context=null;
      try{if(navigator.audioSession)navigator.audioSession.type='playback';}catch{}
      if(wasActive)this.send('mic_off');
    }
  }
  root.GroveVoice={detectPitch,VoiceInput};
  if(typeof module!=='undefined')module.exports=root.GroveVoice;
})(typeof window!=='undefined'?window:globalThis);
