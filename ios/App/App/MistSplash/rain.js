// 0911 通话页的雨。从开屏那套水面（splash.js）拆出来：只留自动落下的雨滴波纹，
// 没有雾、没有擦痕、没有文字，也不接手指——她说「这次不是我手动的，换成雨滴那种感觉」。
// 波纹公式照抄 splash.js 着色器里 rain[] 那一段，改成圈更小、散得更快、同时落得更多。
(()=>{
  const root=document.getElementById('call-rain'),canvas=root.querySelector('canvas'),photo=root.querySelector('img');
  const post=action=>{window.webkit?.messageHandlers?.callRain?.postMessage(action)};
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const MAX=8;                       // 同时最多几滴在荡
  const LIFE=3;                      // 一滴从落下到散完（秒）
  let W=0,H=0,aspect=1,gl=null,program=null,texture=null,buffer=null,render=null;
  let drops=[],clock=0,previous=0,nextDrop=0,active=true,stopped=false,raf=0,revealed=false,source=null;
  const uniform=new Float32Array(MAX*4);
  const reveal=()=>{if(revealed)return;revealed=true;root.style.opacity='1'};
  setTimeout(reveal,4000);           // 保险：一帧都没画出来也别永远隐身

  // 普通 cover：居中裁切铺满。不用开屏那种「保留两边、中间吃变形」的映射，壁纸里有人像会被拉歪
  function backdrop(src){
    const S=Math.min(2,window.devicePixelRatio||2),r=root.getBoundingClientRect();
    W=Math.max(1,Math.round(r.width*S));H=Math.max(1,Math.round(r.height*S));aspect=H/W;
    const c=document.createElement('canvas');c.width=W;c.height=H;const x=c.getContext('2d');
    const pw=src.naturalWidth||src.width,ph=src.naturalHeight||src.height;
    if(!pw||!ph)throw Error('photo not decoded');
    const scale=Math.max(W/pw,H/ph),dw=pw*scale,dh=ph*scale;
    x.drawImage(src,(W-dw)/2,(H-dh)/2,dw,dh);
    // 开屏 0909 踩过的坑：位图被系统回收时 drawImage 静默失败，画完回头看一眼中心点
    if(x.getImageData(W>>1,H>>1,1,1).data[3]===0)throw Error('photo drew nothing');
    return c;
  }

  const vertex='attribute vec2 a;varying vec2 uv;void main(){uv=vec2((a.x+1.)*.5,(1.-a.y)*.5);gl_Position=vec4(a,0.,1.);}';
  const fragment=`precision highp float;varying vec2 uv;uniform sampler2D photograph;uniform vec4 drops[${MAX}];uniform float aspect;
  void main(){vec2 p=uv;vec2 dis=vec2(0.);float light=0.;
    for(int i=0;i<${MAX};i++){vec4 q=drops[i];if(q.w<=0.)continue;
      vec2 d=(p-q.xy)*vec2(1.,aspect);float dist=length(d);
      float phase=dist-q.z*.052;
      float env=exp(-pow(phase/.024,2.))*exp(-q.z*1.15)*smoothstep(0.,.08,q.z)*(1.-smoothstep(${(LIFE-0.8).toFixed(1)},${LIFE.toFixed(1)},q.z));
      float wave=sin(phase*330.)*env*q.w;
      vec2 n=d/max(dist,.002);
      dis+=n*vec2(.010,.010/aspect)*wave;light+=dot(n,vec2(-.447,-.894))*wave*.10;}
    vec3 color=texture2D(photograph,clamp(p+dis,.002,.998)).rgb+light;gl_FragColor=vec4(color,1.);}`;

  function setup(){
    const bg=backdrop(source);
    canvas.width=W;canvas.height=H;
    gl=canvas.getContext('webgl',{alpha:false,antialias:false,powerPreference:'low-power'});
    if(!gl)throw Error('no webgl');
    const shader=(kind,code)=>{const s=gl.createShader(kind);gl.shaderSource(s,code);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s};
    program=gl.createProgram();gl.attachShader(program,shader(gl.VERTEX_SHADER,vertex));gl.attachShader(program,shader(gl.FRAGMENT_SHADER,fragment));gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));
    gl.useProgram(program);
    buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);
    const attr=gl.getAttribLocation(program,'a');gl.enableVertexAttribArray(attr);gl.vertexAttribPointer(attr,2,gl.FLOAT,false,0,0);
    texture=gl.createTexture();gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,texture);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,bg);
    gl.uniform1i(gl.getUniformLocation(program,'photograph'),0);
    gl.uniform1f(gl.getUniformLocation(program,'aspect'),aspect);
    const dropsLoc=gl.getUniformLocation(program,'drops[0]');
    gl.viewport(0,0,W,H);
    render=()=>{gl.uniform4fv(dropsLoc,uniform);gl.drawArrays(gl.TRIANGLES,0,6)};
    root.dataset.renderer='webgl';
    raf=requestAnimationFrame(frame);
  }

  // 一两秒落一两滴，不是暴雨；位置避开四个边缘，免得圈只露半个
  function updateDrops(){
    drops=drops.filter(d=>clock-d.born<LIFE);
    if(!reduce&&clock>=nextDrop&&drops.length<MAX){
      drops.push({x:.06+Math.random()*.88,y:.08+Math.random()*.84,born:clock,power:.55+Math.random()*.5});
      nextDrop=clock+.35+Math.random()*.9;
    }
    uniform.fill(0);drops.forEach((d,i)=>uniform.set([d.x,d.y,clock-d.born,d.power],i*4));
    root.dataset.drops=String(drops.length);
  }

  // 约 30 帧；切后台 / 通话页缩成胶囊时 Swift 传 active:false，停着不画
  function frame(now){
    try{
      if(stopped)return;
      if(!active||document.hidden){previous=now;raf=requestAnimationFrame(frame);return}
      if(now-previous<32){raf=requestAnimationFrame(frame);return}
      const dt=previous?Math.min(.06,(now-previous)/1000):.033;previous=now;clock+=dt;
      updateDrops();render();reveal();
      root.dataset.frame=String((Number(root.dataset.frame)||0)+1);
      raf=requestAnimationFrame(frame);
    }catch(error){root.dataset.frameError=String(error&&error.message||error);stopped=true;post('failed')}
  }

  window.callRainEnvironment=config=>{active=config.active!==false;root.dataset.active=String(active)};
  window.callRainStop=()=>{stopped=true;cancelAnimationFrame(raf);if(gl){texture&&gl.deleteTexture(texture);buffer&&gl.deleteBuffer(buffer);program&&gl.deleteProgram(program)}};

  // 开屏 0909 那套：优先 createImageBitmap 拿不会被回收的位图；失败隔 300ms 重来，三次都不行交给原生静态壁纸
  let attempts=0;
  const start=()=>{
    attempts++;
    const run=()=>{try{setup()}catch(error){root.dataset.startError=String(error&&error.message||error);if(attempts<3){source=null;setTimeout(start,300)}else post('failed')}};
    if(source){run();return}
    const useImg=()=>{source=photo;run()};
    if(window.createImageBitmap)createImageBitmap(photo).then(bitmap=>{source=bitmap;run()},useImg);else useImg();
  };
  photo.addEventListener('error',()=>post('failed'),{once:true});
  if(photo.complete&&photo.naturalWidth)start();else photo.addEventListener('load',start,{once:true});
})();
