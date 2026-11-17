const fs=require('fs'),path=require('path');
const puppeteer=require(process.env.APPDATA+'/npm/node_modules/puppeteer');
const work=__dirname,out=path.dirname(work);
const B=Buffer;
function u32(...ns){let b=B.alloc(ns.length*4);ns.forEach((n,i)=>b.writeUInt32BE(n>>>0,i*4));return b}
function u16(...ns){let b=B.alloc(ns.length*2);ns.forEach((n,i)=>b.writeUInt16BE(n,i*2));return b}
function box(type,...data){data=B.concat(data.map(x=>B.isBuffer(x)?x:B.from(x)));return B.concat([u32(data.length+8),B.from(type),data])}
function full(type,v,flags,...data){return box(type,B.from([v,flags>>16,flags>>8,flags]),...data)}
const zeros=n=>B.alloc(n),matrix=u32(65536,0,0,0,65536,0,0,0,0x40000000);
function runTable(values){let runs=[];for(const n of values){if(runs.length&&runs.at(-1)[1]===n)runs.at(-1)[0]++;else runs.push([1,n])}return B.concat([u32(runs.length),...runs.map(r=>u32(...r))])}
function descriptor(tag,payload){let n=payload.length,len=[n&127];while(n>>=7)len.unshift((n&127)|128);return B.concat([B.from([tag,...len]),payload])}
function mux(video,audio,vdesc,adesc){
 const ftyp=box('ftyp','isom',u32(512),'isomiso2avc1mp41');
 const vdata=B.concat(video.map(v=>v.data)),adata=B.concat(audio.map(a=>a.data));
 const mdat=box('mdat',vdata,adata);
 function track(samples,id,kind,desc,offset){
  const isV=kind==='vide',timescale=isV?90000:48000,total=timescale*90;
  let durations=isV?samples.map(()=>3000):samples.map(()=>1024);
  if(!isV){while(durations.reduce((a,b)=>a+b,0)>total+1024){samples.pop();durations.pop()}durations[durations.length-1]=total-durations.slice(0,-1).reduce((a,b)=>a+b,0)}
  const tkhd=full('tkhd',0,7,u32(0,0,id,0,90000),zeros(8),u16(0,0,isV?0:256,0),matrix,u32(isV?1920*65536:0,isV?1080*65536:0));
  const mdhd=full('mdhd',0,0,u32(0,0,timescale,total),u16(0x55c4,0));
  const hdlr=full('hdlr',0,0,u32(0),kind,zeros(12),isV?'StyleSync Video\0':'Original Soundtrack\0');
  let entry;
  if(isV){let name=zeros(32);name[0]=9;name.write('StyleSync',1);entry=box('avc1',zeros(6),u16(1),zeros(16),u16(1920,1080),u32(0x00480000,0x00480000,0),u16(1),name,u16(24,0xffff),box('avcC',desc))}
  else {const esds=descriptor(3,B.concat([u16(2),B.from([0]),descriptor(4,B.concat([B.from([0x40,0x15,0,0,0]),u32(192000,192000),descriptor(5,desc)])),descriptor(6,B.from([2]))]));entry=box('mp4a',zeros(6),u16(1),zeros(8),u16(2,16,0,0),u32(48000*65536),full('esds',0,0,esds))}
  const stsd=full('stsd',0,0,u32(1),entry),stts=full('stts',0,0,runTable(durations));
  const stsc=full('stsc',0,0,u32(1,1,samples.length,1));
  const stsz=full('stsz',0,0,u32(0,samples.length),u32(...samples.map(s=>s.data.length)));
  const stco=full('stco',0,0,u32(1,offset));
  const stss=isV?full('stss',0,0,u32(samples.filter(s=>s.key).length),u32(...samples.map((s,i)=>s.key?i+1:0).filter(Boolean))):zeros(0);
  const stbl=box('stbl',stsd,stts,stsc,stsz,stco,stss);
  const mediaHeader=isV?full('vmhd',0,1,u16(0,0,0,0)):full('smhd',0,0,u16(0,0));
  const dinf=box('dinf',full('dref',0,0,u32(1),full('url ',0,1)));
  return box('trak',tkhd,box('mdia',mdhd,hdlr,box('minf',mediaHeader,dinf,stbl)));
 }
 const mvhd=full('mvhd',0,0,u32(0,0,1000,90000,65536),u16(256,0),zeros(8),matrix,zeros(24),u32(3));
 const moov=box('moov',mvhd,track(video,1,'vide',vdesc,ftyp.length+8),track(audio,2,'soun',adesc,ftyp.length+8+vdata.length));
 fs.writeFileSync(path.join(out,'brag.mp4'),B.concat([ftyp,mdat,moov]));
 return {videoFrames:video.length,audioSamples:audio.length,seconds:90,width:1920,height:1080,fps:30,bytes:fs.statSync(path.join(out,'brag.mp4')).size};
}
(async()=>{
 const browser=await puppeteer.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,pipe:true,userDataDir:path.join(work,'chrome-profile'),args:['--no-sandbox','--disable-gpu','--allow-file-access-from-files']});
 try {
 const page=await browser.newPage();await page.setViewport({width:1920,height:1080,deviceScaleFactor:1});
 page.on('pageerror',e=>console.error('PAGE',e.message));
 await page.goto('file:///'+path.join(work,'film.html').replaceAll('\\','/'));await page.evaluate(()=>ready);
 // Representative settled frames plus calculated transition entry/exit endpoints.
 const ts=[2.5,8,16,24,34,44,54,63,73,81.5,88];
 const contact=await page.evaluate(async times=>{let sheet=document.createElement('canvas');sheet.width=1920;sheet.height=Math.ceil(times.length/4)*300;let ctx=sheet.getContext('2d');ctx.fillStyle='#ddd';ctx.fillRect(0,0,sheet.width,sheet.height);times.forEach((t,i)=>{draw(t);ctx.drawImage(c,(i%4)*480,Math.floor(i/4)*300,480,270);ctx.fillStyle='#222';ctx.font='18px Arial';ctx.fillText(t.toFixed(2)+' sec',(i%4)*480+10,Math.floor(i/4)*300+277)});return sheet.toDataURL('image/jpeg',.9).split(',')[1]},ts);
 fs.writeFileSync(path.join(work,'scene-contact-sheet.jpg'),B.from(contact,'base64'));
 const transitionTimes=[4,10,20,28,38,48,58,66,78,84].flatMap(t=>[t-.4,t-1/30,t,t+.4]);
 const transition=await page.evaluate(async times=>{let sheet=document.createElement('canvas');sheet.width=1920;sheet.height=Math.ceil(times.length/4)*300;let ctx=sheet.getContext('2d');ctx.fillStyle='#ddd';ctx.fillRect(0,0,sheet.width,sheet.height);times.forEach((t,i)=>{draw(t);ctx.drawImage(c,(i%4)*480,Math.floor(i/4)*300,480,270);ctx.fillStyle='#222';ctx.font='18px Arial';ctx.fillText(t.toFixed(3)+' sec',(i%4)*480+10,Math.floor(i/4)*300+277)});return sheet.toDataURL('image/jpeg',.8).split(',')[1]},transitionTimes);
 fs.writeFileSync(path.join(work,'transition-contact-sheet.jpg'),B.from(transition,'base64'));
 const poster=await page.evaluate(()=>{draw(8);return c.toDataURL('image/jpeg',.96).split(',')[1]});fs.writeFileSync(path.join(out,'brag.jpg'),B.from(poster,'base64'));
 if(process.argv.includes('--preview')){console.log('Preview frames ready');return}
 const video=[],audio=[];let vdesc,adesc;
 await page.exposeFunction('receiveEncoded',(kind,batch,description)=>{const target=kind==='video'?video:audio;for(const v of batch)target.push({...v,data:B.from(v.b64,'base64')});if(description){if(kind==='video')vdesc=B.from(description,'base64');else adesc=B.from(description,'base64')}});
 await page.exposeFunction('report',s=>console.log(s));
 await page.evaluate(async()=>{
  const b64=arr=>{let s='';for(let i=0;i<arr.length;i+=32768)s+=String.fromCharCode(...arr.subarray(i,i+32768));return btoa(s)};
  let pending=[],vd=null,err=null;
  const enc=new VideoEncoder({output:(chunk,meta)=>{let data=new Uint8Array(chunk.byteLength);chunk.copyTo(data);pending.push({b64:b64(data),key:chunk.type==='key',timestamp:chunk.timestamp});if(meta?.decoderConfig?.description)vd=b64(new Uint8Array(meta.decoderConfig.description))},error:e=>{err=e.message}});
  enc.configure({codec:'avc1.420028',width:1920,height:1080,bitrate:4500000,framerate:30,latencyMode:'realtime',avc:{format:'avc'}});
  for(let frame=0;frame<2700;frame++){
   draw(frame===0?8:frame/30);
   const f=new VideoFrame(c,{timestamp:Math.round(frame*1e6/30),duration:Math.round(1e6/30)});enc.encode(f,{keyFrame:frame%60===0});f.close();
   if(frame%60===59){await enc.flush();if(err)throw Error(err);await receiveEncoded('video',pending,vd);pending=[];vd=null;if(frame%300===299)await report('Video '+(frame+1)+'/2700 frames')}
  }
  await enc.flush();if(pending.length)await receiveEncoded('video',pending,vd);enc.close();
  // Original 120 BPM A-minor groove. All events derive from the same sample clock.
  let ap=[],ad=null;
  const ae=new AudioEncoder({output:(chunk,meta)=>{const a=new Uint8Array(chunk.byteLength);chunk.copyTo(a);ap.push({b64:b64(a),timestamp:chunk.timestamp,key:true});if(meta?.decoderConfig?.description)ad=b64(new Uint8Array(meta.decoderConfig.description))},error:e=>{err=e.message}});
  ae.configure({codec:'mp4a.40.2',sampleRate:48000,numberOfChannels:2,bitrate:192000});
  const sr=48000,total=90*sr,chords=[[57,60,64],[53,57,60],[60,64,67],[55,59,62]],freq=m=>440*2**((m-69)/12);
  let seed=31247;const noise=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2147483648-1};
  for(let offset=0;offset<total;offset+=1024){let n=Math.min(1024,total-offset),data=new Float32Array(n*2);
   for(let j=0;j<n;j++){let t=(offset+j)/sr,beat=t*2,bt=(beat%1)/2,bar=Math.floor(beat/8),chord=chords[bar%4],eighth=(beat*2)%1/4,sixteenth=(beat*4)%1/8;
    let fade=Math.min(1,t/2,(90-t)/4),intro=Math.min(1,t/6),energy=t<4?.3:t<10?.65:t>84?.55:1;
    const kick=.25*Math.sin(2*Math.PI*(48*bt+4*(1-Math.exp(-bt*32))))*Math.exp(-bt*16)*intro;
    const snare=(Math.floor(beat)%4===2?.075*noise()*Math.exp(-bt*27):0)*intro;
    const hat=.025*noise()*Math.exp(-sixteenth*95)*intro;
    const bassFreq=freq(chord[0]-24),bass=.105*(Math.sin(2*Math.PI*bassFreq*t)+.2*Math.sin(4*Math.PI*bassFreq*t))*Math.exp(-bt*3.7)*intro;
    const notes=[0,1,2,1,2,1,0,2],note=chord[notes[Math.floor(beat*2)%8]]+12;
    const arp=.072*(Math.sin(2*Math.PI*freq(note)*t)+.12*Math.sin(4*Math.PI*freq(note)*t))*Math.exp(-eighth*16)*Math.min(1,t/3);
    let padL=0,padR=0;for(const m of chord){padL+=Math.sin(2*Math.PI*freq(m)*t)*.026;padR+=Math.sin(2*Math.PI*freq(m)*1.001*t)*.026}
    const soft=kick+snare+hat+bass+arp;
    data[j]=Math.tanh((soft+padL)*1.1)*.65*fade*energy;data[n+j]=Math.tanh((soft+padR)*1.1)*.65*fade*energy;
   }
   const af=new AudioData({format:'f32-planar',sampleRate:sr,numberOfFrames:n,numberOfChannels:2,timestamp:Math.round(offset*1e6/sr),data});ae.encode(af);af.close();
   if(offset%(1024*128)===0){await ae.flush();if(err)throw Error(err);await receiveEncoded('audio',ap,ad);ap=[];ad=null}
  }
  await ae.flush();await receiveEncoded('audio',ap,ad);ae.close();await report('Original soundtrack encoded');
 });
 if(video.length!==2700)throw Error('Video frame count '+video.length);
 if(!vdesc||!adesc)throw Error('Missing codec configuration');
 const stats=mux(video,audio,vdesc,adesc);fs.writeFileSync(path.join(work,'render-stats.json'),JSON.stringify(stats,null,2));console.log(JSON.stringify(stats));
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
