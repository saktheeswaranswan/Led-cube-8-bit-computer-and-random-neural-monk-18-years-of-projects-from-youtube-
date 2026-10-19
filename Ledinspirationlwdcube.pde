/*
  GECKOCUBE DYNAMIC — APDE ANDROID RGB VOXEL STUDIO
  Processing Java Mode / APDE Android, P3D renderer

  FEATURES
  - 16 x 16 x 16 voxel workspace for solids
  - 5 x 7 alphabet text voxels
  - Native Android text-entry dialog
  - Manual touch rotation and auto-rotation
  - ISO / FRONT / BACK / LEFT / RIGHT / TOP / BOTTOM views
  - Left-to-right and right-to-left scrolling
  - 50 text/voxel animation effects
  - RGB palette, 16 shapes, cursor controls
  - Multiplexing and persistence-of-vision simulation

  NOTE: Visual simulation only; not physical LED hardware control.
*/

import java.util.ArrayList;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.text.InputType;
import android.view.WindowManager;
import android.widget.EditText;

final int WORDS = 0;
final int SOLIDS = 1;
final int GX = 16, GY = 16, GZ = 16;
final int MAX_TEXT_CHARS = 25;

int dimX=16, dimY=16, dimZ=16;
int[][][] voxels;
long[][][] lastLitNanos;

final int[] COLORS={
  0xFFFF3030,0xFF30FF60,0xFF4080FF,0xFF20E8FF,
  0xFFFF40E8,0xFFFFE830,0xFFFFFFFF,0xFFFF9020
};

final String[] COLOR_NAMES={
  "RED","GREEN","BLUE","CYAN",
  "MAGENTA","YELLOW","WHITE","ORANGE"
};

final String[] FONT5X7={
"01110/10001/10001/11111/10001/10001/10001",
"11110/10001/10001/11110/10001/10001/11110",
"01111/10000/10000/10000/10000/10000/01111",
"11110/10001/10001/10001/10001/10001/11110",
"11111/10000/10000/11110/10000/10000/11111",
"11111/10000/10000/11110/10000/10000/10000",
"01111/10000/10000/10111/10001/10001/01111",
"10001/10001/10001/11111/10001/10001/10001",
"11111/00100/00100/00100/00100/00100/11111",
"00111/00010/00010/00010/00010/10010/01100",
"10001/10010/10100/11000/10100/10010/10001",
"10000/10000/10000/10000/10000/10000/11111",
"10001/11011/10101/10101/10001/10001/10001",
"10001/11001/11001/10101/10011/10011/10001",
"01110/10001/10001/10001/10001/10001/01110",
"11110/10001/10001/11110/10000/10000/10000",
"01110/10001/10001/10001/10101/10010/01101",
"11110/10001/10001/11110/10100/10010/10001",
"01111/10000/10000/01110/00001/00001/11110",
"11111/00100/00100/00100/00100/00100/00100",
"10001/10001/10001/10001/10001/10001/01110",
"10001/10001/10001/10001/10001/01010/00100",
"10001/10001/10001/10101/10101/11011/10001",
"10001/10001/01010/00100/01010/10001/10001",
"10001/10001/01010/00100/00100/00100/00100",
"11111/00001/00010/00100/01000/10000/11111"
};

final String[] SHAPES={
  "CUBE","RECT PRISM","TRI PRISM","SQUARE PRISM",
  "PENT PRISM","HEX PRISM","OCT PRISM","WEDGE",
  "SPHERE","HEMISPHERE","CYLINDER","CONE",
  "TORUS","PYRAMID","TETRAHEDRON","OCTAHEDRON"
};

final String[] EFFECTS={
"DISSOLVE","RANDOM PIXELS","RAIN","WAVE","RIPPLE",
"FIRE","OCEAN","RAINBOW","GLITCH","FLICKER",
"SPARKLE","SCANLINE","RADAR","PULSE","HEARTBEAT",
"EXPLODE","ASSEMBLE","MATRIX RAIN","STARFIELD","SNAKE",
"HORIZONTAL WIPE","VERTICAL WIPE","DIAGONAL WIPE",
"CIRCLE WIPE","REVERSE WIPE","SHIMMER","GLOW PULSE",
"COLOR CYCLE","NOISE","STROBE","PIXEL SWAP","CROSS WIPE",
"SPIRAL WIPE","BOUNCE","BREATHING","ECHO","MIRROR WAVE",
"COMET","PLASMA","CONFETTI","DIGITAL RAIN","RANDOM FADE",
"EDGE IN","EDGE OUT","CENTER IN","CENTER OUT",
"CHECKERBOARD","ZOOM PULSE","TWINKLE","PARTICLE DISSOLVE"
};

String inputText="WELCOME TO GECKOCUBE";
String[] words=new String[0];

int wordIndex=0, mode=WORDS, colorIndex=3;
int shapeIndex=0, shapeSize=6;
int cursorX=8,cursorY=8,cursorZ=8,cursorStep=1;

float rotX=-0.48f,rotY=0.65f,autoRot=0,zoom=1.0f;

boolean autoRotate=true,blink=false,blinkOn=true;
boolean mux=false,autoWords=false;
boolean dragging=false,muxSliderDragging=false;
boolean scrolling=false,scrollRTL=true;

float lastX,lastY,speedSlider=50,scrollSpeed=1.0f;

long blinkAt=0,wordAt=0,lastScanNanos=0;
long lastScrollAt=0,effectStart=0;

String status="READY";
long statusUntil=0;
int activeEffect=-1;

PFont fontSmall,fontMedium,fontLarge;

float topH,bottomH,panelW,viewX,viewY,viewW,viewH,scaleUI;

int[] activeVoxelIndices=new int[0];
int activeVoxelCount=0,scanIndex=0;
long scanStepsTotal=0;

String scrollSource="";
int scrollOffset=0;

void settings(){
  fullScreen(P3D);
}

void setup(){
  orientation(LANDSCAPE);
  frameRate(60);
  smooth(4);

  fontSmall=createFont("SansSerif",13,true);
  fontMedium=createFont("SansSerif",17,true);
  fontLarge=createFont("SansSerif",24,true);

  allocateGrid(16,16,16);
  parseWords();
  buildCurrentWord();
  setStatus("GECKOCUBE READY");
}

void draw(){
  background(5,8,15);
  calculateLayout();
  updateAnimation();

  hint(DISABLE_DEPTH_TEST);
  drawTopBar();
  hint(ENABLE_DEPTH_TEST);

  drawCubeView();

  hint(DISABLE_DEPTH_TEST);
  drawControlPanel();
  drawStatus();
  hint(ENABLE_DEPTH_TEST);
}

void calculateLayout(){
  scaleUI=constrain(min(width/900.0f,height/500.0f),0.65f,1.35f);

  topH=max(48,height*0.12f);
  bottomH=min(max(190,height*0.43f),height*0.53f);

  panelW=width*0.44f;
  viewX=panelW;
  viewY=topH;
  viewW=width-panelW;
  viewH=max(40,height-topH-bottomH);
}

void updateAnimation(){
  if(autoRotate) autoRot=(autoRot+0.008f)%TWO_PI;

  if(blink && millis()-blinkAt>350){
    blinkAt=millis();
    blinkOn=!blinkOn;
  }else if(!blink){
    blinkOn=true;
  }

  if(mode==WORDS && autoWords && millis()-wordAt>2200){
    wordAt=millis();
    nextWord();
  }

  if(scrolling && mode==WORDS &&
     millis()-lastScrollAt>max(35,220/(scrollSpeed+0.25f))){
    lastScrollAt=millis();
    advanceScroll();
  }

  if(mux) advanceMultiplex();
}

void drawTopBar(){
  noStroke();
  fill(20,27,42);
  rect(0,0,width,topH);

  fill(245);
  textFont(fontLarge);
  textAlign(LEFT,CENTER);
  text("GECKOCUBE",12,topH*0.38f);

  fill(145,165,190);
  textFont(fontSmall);
  text(dimX+" x "+dimY+" x "+dimZ+" | "+
       activeVoxelCount+" ACTIVE VOXELS",13,topH*0.78f);

  float bw=max(60,min(94,width*0.095f));
  float bh=min(32,topH*0.58f);
  float by=(topH-bh)*0.5f;
  float bx=width-2*bw-22;

  drawButton("WORDS",bx,by,bw,bh,mode==WORDS);
  drawButton("SOLIDS",bx+bw+7,by,bw,bh,mode==SOLIDS);
}

void drawCubeView(){
  hint(DISABLE_DEPTH_TEST);
  noStroke();
  fill(2,4,9);
  rect(viewX,viewY,viewW,viewH);
  hint(ENABLE_DEPTH_TEST);

  float maxDim=max(dimX,max(dimY,dimZ));
  float cubeSize=min(viewW,viewH)*0.70f*zoom;
  cubeSize=min(cubeSize,min(viewW,viewH)*0.86f);
  cubeSize=max(20,cubeSize);

  float gap=cubeSize/maxDim;
  float sx=dimX*gap;
  float sy=dimY*gap;
  float sz=dimZ*gap;

  pushMatrix();
  translate(viewX+viewW*0.5f,viewY+viewH*0.49f);
  rotateX(rotX);
  rotateY(rotY+autoRot);

  drawWireBox(sx,sy,sz);
  drawVoxels(gap,sx,sy,sz);

  if(mode==SOLIDS) drawCursor(gap,sx,sy,sz);

  popMatrix();

  hint(DISABLE_DEPTH_TEST);
  fill(160,180,205);
  textFont(fontSmall);
  textAlign(LEFT,TOP);
  text("3D VIEW - DRAG TO ROTATE",viewX+8,viewY+5);

  fill(245);
  text(mode==WORDS?currentWordText():SHAPES[shapeIndex],
       viewX+8,viewY+22);

  if(activeEffect>=0 && mode==WORDS){
    fill(255,210,100);
    text("EFFECT: "+EFFECTS[activeEffect],viewX+8,viewY+39);
  }

  if(mux){
    fill(60,240,180);
    text("MUX "+nf(multiplexIntervalMs(),0,2)+" ms target dwell",
         viewX+8,viewY+56);
  }

  drawViewButtons();
  textAlign(LEFT,BASELINE);
  hint(ENABLE_DEPTH_TEST);
}

void drawViewButtons(){
  float y=viewY+viewH-29;
  String[] labels={
    "ISO","FRONT","BACK","LEFT","RIGHT","TOP","BOTTOM","STOP","AUTO"
  };

  float gap=3;
  float w=(viewW-16-gap*(labels.length-1))/labels.length;
  float x=viewX+8;

  for(int i=0;i<labels.length;i++){
    boolean active=(i==7&&!autoRotate)||(i==8&&autoRotate);
    drawButton(labels[i],x+i*(w+gap),y,w,24,active);
  }
}

void drawWireBox(float sx,float sy,float sz){
  stroke(65,90,125,190);
  strokeWeight(1);
  noFill();
  box(sx,sy,sz);
}

long multiplexIntervalNanos(){
  float t=constrain(speedSlider/100.0f,0,1);
  float dwellMs=200.0f*pow(0.2f/200.0f,t);
  return Math.max(200000L,(long)(dwellMs*1000000.0f));
}

float multiplexIntervalMs(){
  return multiplexIntervalNanos()/1000000.0f;
}

long persistenceWindowNanos(){
  float t=constrain(speedSlider/100.0f,0,1);
  float windowMs=lerp(multiplexIntervalMs()*0.8f,180.0f,t*t);
  return Math.max(200000L,(long)(windowMs*1000000.0f));
}

void advanceMultiplex(){
  if(activeVoxelCount==0) return;

  long now=System.nanoTime();
  long interval=multiplexIntervalNanos();

  if(lastScanNanos==0){
    lastScanNanos=now;
    illuminateScannedVoxel(scanIndex,now);
    return;
  }

  long elapsed=now-lastScanNanos;
  if(elapsed<interval) return;

  long stepsLong=elapsed/interval;
  int steps=(int)Math.min(stepsLong,100000L);

  for(int i=0;i<steps;i++){
    scanIndex++;
    if(scanIndex>=activeVoxelCount) scanIndex=0;
    illuminateScannedVoxel(scanIndex,now);
  }

  scanStepsTotal+=steps;
  lastScanNanos+=stepsLong*interval;

  if(now-lastScanNanos>interval*4L) lastScanNanos=now;
}

void illuminateScannedVoxel(int i,long now){
  if(i<0||i>=activeVoxelCount) return;

  int n=activeVoxelIndices[i];
  int x=n%dimX;
  int y=(n/dimX)%dimY;
  int z=n/(dimX*dimY);

  if(valid(x,y,z)&&voxels[z][y][x]!=0){
    lastLitNanos[z][y][x]=now;
  }
}

void resetMultiplex(){
  scanIndex=0;
  scanStepsTotal=0;
  lastScanNanos=System.nanoTime();

  if(mux&&activeVoxelCount>0){
    illuminateScannedVoxel(0,lastScanNanos);
  }
}

void rebuildMultiplexList(){
  ArrayList<Integer> a=new ArrayList<Integer>();

  for(int z=0;z<dimZ;z++){
    for(int y=0;y<dimY;y++){
      for(int x=0;x<dimX;x++){
        if(voxels[z][y][x]!=0){
          a.add(z*dimY*dimX+y*dimX+x);
        }
      }
    }
  }

  activeVoxelCount=a.size();
  activeVoxelIndices=new int[activeVoxelCount];

  for(int i=0;i<activeVoxelCount;i++){
    activeVoxelIndices[i]=a.get(i);
  }

  if(activeVoxelCount==0) scanIndex=0;
  else scanIndex%=activeVoxelCount;
}

void allocateGrid(int dx,int dy,int dz){
  dimX=constrain(dx,1,160);
  dimY=constrain(dy,1,16);
  dimZ=constrain(dz,1,16);

  voxels=new int[dimZ][dimY][dimX];
  lastLitNanos=new long[dimZ][dimY][dimX];

  cursorX=constrain(cursorX,0,dimX-1);
  cursorY=constrain(cursorY,0,dimY-1);
  cursorZ=constrain(cursorZ,0,dimZ-1);

  activeVoxelIndices=new int[0];
  activeVoxelCount=0;
  scanIndex=0;
}

void drawVoxels(float gap,float sx,float sy,float sz){
  float hx=sx*0.5f;
  float hy=sy*0.5f;
  float hz=sz*0.5f;
  float ledSize=max(1.4f,gap*0.62f);

  long now=System.nanoTime();
  long persistence=persistenceWindowNanos();
  int selected=-1;

  if(mux&&activeVoxelCount>0){
    selected=activeVoxelIndices[
      constrain(scanIndex,0,activeVoxelCount-1)
    ];
  }

  noStroke();

  for(int z=0;z<dimZ;z++){
    for(int y=0;y<dimY;y++){
      for(int x=0;x<dimX;x++){
        int c=voxels[z][y][x];

        if(c==0||(blink&&!blinkOn)) continue;

        int linear=z*dimY*dimX+y*dimX+x;

        if(mode==WORDS && activeEffect>=0 &&
           !effectVisible(activeEffect,x,y,z,linear,
           millis()-effectStart,dimX,dimY,dimZ)){
          continue;
        }

        float brightness=1.0f;

        if(mux){
          long lit=lastLitNanos[z][y][x];
          if(lit==0) continue;

          long age=Math.max(0L,now-lit);
          if(age>=persistence) continue;

          float ratio=age/(float)persistence;
          brightness=max(0.035f,(1-ratio)*(1-ratio));
        }

        if(mode==WORDS&&activeEffect>=0){
          c=effectColor(activeEffect,c,x,y,z,millis()-effectStart);
        }

        float px=-hx+(x+0.5f)*gap;
        float py=-hy+(y+0.5f)*gap;
        float pz=-hz+(z+0.5f)*gap;

        pushMatrix();
        translate(px,py,pz);
        fill(red(c)*brightness,green(c)*brightness,blue(c)*brightness);
        box(ledSize);

        if(mux&&linear==selected){
          fill(255);
          box(max(1,ledSize*0.27f));
        }

        popMatrix();
      }
    }
  }
}

boolean effectVisible(int e,int x,int y,int z,int n,
                      long t,int dx,int dy,int dz){
  float p=(t%2200)/2200.0f;
  float r=randomSeedValue(n,e);
  float cx=(dx-1)*0.5f;
  float cy=(dy-1)*0.5f;
  float cz=(dz-1)*0.5f;

  switch(e){
    case 0:
    case 25:
    case 41:
    case 49:
      return r<p;

    case 1:
      return r<0.35f+0.65f*abs(sin(t*0.012f+n));

    case 2:
    case 19:
    case 30:
    case 36:
      return ((x+(int)(t/90))%max(1,dx))<max(1,dx/3);

    case 3:
    case 4:
    case 26:
    case 35:
      return abs(y-(cy+sin(x*0.55f+t*0.006f)*cy*0.8f))<2.4f;

    case 5:
      return randomSeedValue(n,(int)(t/100))<0.72f;

    case 6:
    case 7:
    case 27:
    case 38:
      return true;

    case 8:
    case 28:
      return randomSeedValue(n,(int)(t/90))>0.25f;

    case 9:
    case 14:
    case 29:
    case 34:
      return sin(t*0.012f+n*0.03f)>-0.15f;

    case 10:
    case 48:
      return randomSeedValue(n,(int)(t/180))>0.35f;

    case 11:
      return (x+(int)(t/70))%4==0;

    case 12:
      return abs(dist(x,y,cx,cy)-((t/10.0f)%max(dx,dy)))<2.0f;

    case 13:
    case 33:
    case 47:
      return 0.35f+0.65f*sin(t*0.004f)>0.3f;

    case 15:
      return randomSeedValue(n,(int)(t/260))<p;

    case 16:
      return randomSeedValue(n,e)<p;

    case 17:
    case 20:
    case 21:
    case 22:
    case 23:
    case 24:
    case 31:
    case 32:
    case 42:
    case 43:
    case 44:
    case 45:
    case 46:
      return wipeVisible(e,x,y,z,p,dx,dy,dz);

    case 18:
    case 39:
      return randomSeedValue(n,(int)(t/130))>0.7f;

    case 37:
      return x==((int)(t/100)%max(1,dx)) ||
             x==((int)(t/100)%max(1,dx))-1;

    case 40:
      return randomSeedValue(n,(int)(t/120))>0.28f;

    default:
      return true;
  }
}

boolean wipeVisible(int e,int x,int y,int z,float p,
                    int dx,int dy,int dz){
  float v=0.0f;

  switch(e){
    case 20:
      v=x/(float)max(1,dx-1);
      break;
    case 21:
      v=y/(float)max(1,dy-1);
      break;
    case 22:
      v=(x+y+z)/(float)max(1,dx+dy+dz-3);
      break;
    case 23:
      v=dist(x,z,dx*0.5f,dz*0.5f)/
        max(1,dist(0,0,dx*0.5f,dz*0.5f));
      break;
    case 24:
      v=1-x/(float)max(1,dx-1);
      break;
    case 31:
      v=((x+y+z)%2==0)?0.25f:0.75f;
      break;
    case 32:
      v=(atan2(y-dy/2.0f,x-dx/2.0f)+PI)/TWO_PI;
      break;
    case 42:
      v=min(min(x,dx-1-x),min(y,dy-1-y))/
        (float)max(1,min(dx,dy)*0.5f);
      break;
    case 43:
      v=1-min(min(x,dx-1-x),min(y,dy-1-y))/
        (float)max(1,min(dx,dy)*0.5f);
      break;
    case 44:
      v=dist(x,y,dx/2.0f,dy/2.0f)/
        max(1,dist(0,0,dx/2.0f,dy/2.0f));
      break;
    case 45:
      v=1-dist(x,y,dx/2.0f,dy/2.0f)/
        max(1,dist(0,0,dx/2.0f,dy/2.0f));
      break;
    default:
      v=x/(float)max(1,dx-1);
  }

  if(e==24||e==43||e==45) return v>p;
  return v<p;
}

float randomSeedValue(int a,int b){
  int n=a*1103515245+b*12345+1013904223;
  n=(n^(n>>>16))*0x45d9f3b;
  n=(n^(n>>>16))*0x45d9f3b;
  n=n^(n>>>16);
  return (n&0x7fffffff)/(float)2147483647.0f;
}

int effectColor(int effect,int c,int x,int y,int z,long t){
  if(effect==7||effect==27||effect==38||effect==39){
    float h=(x*13+y*7+z*5+t*0.08f)%255;
    return color((h+255)%255,220,255);
  }

  if(effect==5) return color(255,random(80,220),20);
  if(effect==6) return color(20,random(120,240),255);
  if(effect==8||effect==28){
    return random(100)<50?color(255,255,255):c;
  }
  if(effect==12) return color(255,60,random(80,255));
  if(effect==18||effect==39||effect==48) return color(150,220,255);
  if(effect==17||effect==40) return color(80,255,120);
  if(effect==3||effect==4||effect==35||effect==36){
    return color(50,220,255);
  }
  if(effect==10||effect==48) return color(255,255,150);

  return c;
}

void drawCursor(float gap,float sx,float sy,float sz){
  float px=-sx*0.5f+(cursorX+0.5f)*gap;
  float py=-sy*0.5f+(cursorY+0.5f)*gap;
  float pz=-sz*0.5f+(cursorZ+0.5f)*gap;

  pushMatrix();
  translate(px,py,pz);
  noFill();
  stroke(255,255,80);
  strokeWeight(2);
  box(max(4,gap*0.95f));
  popMatrix();
}

void drawControlPanel(){
  noStroke();
  fill(19,25,38);
  rect(0,height-bottomH,panelW,bottomH);

  float x=9,g=5,aw=panelW-18,y=height-bottomH+7;

  if(mode==WORDS){
    fill(175,190,210);
    textFont(fontSmall);
    textAlign(LEFT,BASELINE);
    text("TEXT - tap the field to open Android keyboard",x,y+10);

    y+=14;
    fill(5,8,14);
    stroke(80,105,135);
    rect(x,y,aw,27,5);
    noStroke();
    fill(245);
    textFont(fontMedium);

    String s=inputText;
    if(s.length()>32) s="..."+s.substring(s.length()-29);
    text(s,x+6,y+18);
    y+=32;

    float bw=(aw-3*g)/4;

    drawButton("EDIT TEXT",x,y,bw,25,false);
    drawButton("BUILD",x+bw+g,y,bw,25,false);
    drawButton("PREV",x+2*(bw+g),y,bw,25,false);
    drawButton("NEXT",x+3*(bw+g),y,bw,25,false);
    y+=30;

    drawButton(autoWords?"AUTO WORD ON":"AUTO WORD",x,y,bw,25,autoWords);
    drawButton(scrolling?(scrollRTL?"SCROLL <-":"SCROLL ->"):"SCROLL OFF",
               x+bw+g,y,bw,25,scrolling);
    drawButton("DIR L<->R",x+2*(bw+g),y,bw,25,scrollRTL);
    drawButton("SPEED +",x+3*(bw+g),y,bw,25,false);
    y+=30;

    drawButton("RANDOM FX",x,y,bw,25,activeEffect>=0);
    drawButton("FX OFF",x+bw+g,y,bw,25,false);
    drawButton(mux?"MUX ON":"MUX",x+2*(bw+g),y,bw,25,mux);
    drawButton(blink?"BLINK ON":"BLINK",x+3*(bw+g),y,bw,25,blink);
    y+=30;

    drawButton("ZOOM -",x,y,bw,25,false);
    drawButton("ZOOM +",x+bw+g,y,bw,25,false);
    drawButton("CLEAR",x+2*(bw+g),y,bw,25,false);
    drawButton("SPEED -",x+3*(bw+g),y,bw,25,false);
    y+=29;

    drawPalette(x,y,aw);
  }else{
    fill(175,190,210);
    textFont(fontSmall);
    text("SOLID: "+SHAPES[shapeIndex],x,y+10);
    y+=15;

    float bw=(aw-3*g)/4;

    drawButton("< SHAPE",x,y,bw,25,false);
    drawButton("SHAPE >",x+bw+g,y,bw,25,false);
    drawButton("PLACE",x+2*(bw+g),y,bw,25,false);
    drawButton("CLEAR",x+3*(bw+g),y,bw,25,false);
    y+=30;

    drawButton("SIZE -",x,y,bw,25,false);
    drawButton("SIZE +",x+bw+g,y,bw,25,false);
    drawButton("STEP",x+2*(bw+g),y,bw,25,false);
    drawButton("MUX",x+3*(bw+g),y,bw,25,mux);
    y+=30;

    float cw=(aw-5*g)/6;
    String[] q={"X-","X+","Y-","Y+","Z-","Z+"};

    for(int i=0;i<6;i++){
      drawButton(q[i],x+i*(cw+g),y,cw,24,false);
    }

    y+=27;
    fill(165,180,200);
    text("CURSOR X:"+cursorX+" Y:"+cursorY+" Z:"+cursorZ,x,y+12);
    y+=15;

    drawPalette(x,y,aw);
  }

  drawMuxSlider();
}

void drawPalette(float x,float y,float aw){
  float gap=4;
  float sw=min(24,(aw-45-7*gap)/8);

  fill(160,175,195);
  textFont(fontSmall);
  textAlign(LEFT,BASELINE);
  text("RGB",x,y+16);

  float start=x+38;

  for(int i=0;i<COLORS.length;i++){
    float bx=start+i*(sw+gap);
    stroke(i==colorIndex?color(255):color(65,80,100));
    strokeWeight(i==colorIndex?2:1);
    fill(COLORS[i]);
    rect(bx,y,sw,21,4);
  }

  noStroke();
}

void drawMuxSlider(){
  float y=height-17;
  float sx=64;
  float sw=max(40,panelW-112);

  noStroke();
  fill(50,63,82);
  rect(sx,y-3,sw,6,3);

  fill(35,190,230);
  rect(sx,y-3,sw*speedSlider/100.0f,6,3);

  fill(245);
  textFont(fontSmall);
  textAlign(LEFT,CENTER);
  text("MUX",8,y);
  textAlign(RIGHT,CENTER);
  text(mux?nf(multiplexIntervalMs(),0,2)+"ms":"OFF",panelW-5,y);
  textAlign(LEFT,BASELINE);
}

void drawButton(String label,float x,float y,float w,float h,boolean active){
  stroke(active?color(120,225,255):color(68,82,105));
  strokeWeight(1);
  fill(active?color(35,83,105):color(34,43,60));
  rect(x,y,w,h,5);

  noStroke();
  fill(active?255:220);
  textFont(fontSmall);
  textAlign(CENTER,CENTER);
  text(label,x+w*0.5f,y+h*0.5f);
  textAlign(LEFT,BASELINE);
}

void drawStatus(){
  if(millis()>statusUntil) return;

  float w=min(width*0.65f,460);
  float x=(width-w)*0.5f;
  float y=height-49;

  noStroke();
  fill(0,220);
  rect(x,y,w,23,6);
  fill(255);
  textFont(fontSmall);
  textAlign(CENTER,CENTER);
  text(status,x+w*0.5f,y+11);
  textAlign(LEFT,BASELINE);
}

void parseWords(){
  String cleaned=inputText.toUpperCase().replace('\n',' ').trim();

  if(cleaned.length()==0) cleaned="GECKOCUBE";

  words=splitTokens(cleaned," ,.!?;:-_/");

  if(words==null||words.length==0){
    words=new String[]{"GECKOCUBE"};
  }

  for(int i=0;i<words.length;i++){
    if(words[i].length()>MAX_TEXT_CHARS){
      words[i]=words[i].substring(0,MAX_TEXT_CHARS);
    }
  }

  wordIndex=constrain(wordIndex,0,words.length-1);
}

String currentWordText(){
  if(words==null||words.length==0) return "GECKOCUBE";
  return words[constrain(wordIndex,0,words.length-1)];
}

void buildCurrentWord(){
  String s=currentWordText();
  int reqX=constrain(max(5,s.length()*6-1),5,MAX_TEXT_CHARS*6);

  allocateGrid(reqX,16,16);
  drawTextIntoGrid(s,0);
  rebuildMultiplexList();
  resetMultiplex();
}

void drawTextIntoGrid(String s,int xOffset){
  int ys=(dimY-7)/2;
  int depth=2;
  int zs=(dimZ-depth)/2;

  for(int i=0;i<s.length();i++){
    char ch=s.charAt(i);
    if(ch<'A'||ch>'Z') continue;

    String[] rows=split(FONT5X7[ch-'A'],'/');

    for(int py=0;py<7;py++){
      for(int px=0;px<5;px++){
        int vx=xOffset+i*6+px;

        if(vx<0||vx>=dimX||rows[py].charAt(px)!='1') continue;

        for(int dz=0;dz<depth;dz++){
          setVoxel(vx,ys+py,zs+dz,COLORS[colorIndex]);
        }
      }
    }
  }
}

void nextWord(){
  parseWords();
  wordIndex=(wordIndex+1)%words.length;
  buildCurrentWord();
  setStatus("NEXT: "+currentWordText());
}

void previousWord(){
  parseWords();
  wordIndex=(wordIndex-1+words.length)%words.length;
  buildCurrentWord();
  setStatus("PREVIOUS: "+currentWordText());
}

void clearVoxelsSilently(){
  for(int z=0;z<dimZ;z++){
    for(int y=0;y<dimY;y++){
      for(int x=0;x<dimX;x++){
        voxels[z][y][x]=0;
        lastLitNanos[z][y][x]=0;
      }
    }
  }

  rebuildMultiplexList();
}

void clearVoxels(){
  clearVoxelsSilently();
  resetMultiplex();
  setStatus("CUBE CLEARED");
}

boolean valid(int x,int y,int z){
  return x>=0&&x<dimX&&y>=0&&y<dimY&&z>=0&&z<dimZ;
}

void setVoxel(int x,int y,int z,int c){
  if(valid(x,y,z)){
    voxels[z][y][x]=c;
    lastLitNanos[z][y][x]=0;
  }
}

void moveCursor(int axis,int amount){
  if(axis==0) cursorX=constrain(cursorX+amount,0,dimX-1);
  if(axis==1) cursorY=constrain(cursorY+amount,0,dimY-1);
  if(axis==2) cursorZ=constrain(cursorZ+amount,0,dimZ-1);
}

void placeShape(){
  int c=COLORS[colorIndex];
  int r=max(1,shapeSize/2);

  for(int z=-r;z<=r;z++){
    for(int y=-r;y<=r;y++){
      for(int x=-r;x<=r;x++){
        boolean on=false;
        float d=sqrt(x*x+y*y+z*z);
        float rad=sqrt(x*x+z*z);

        switch(shapeIndex){
          case 0:
            on=abs(x)==r||abs(y)==r||abs(z)==r;
            break;
          case 1:
            on=abs(x)==r||abs(y)==max(1,r/2)||abs(z)==max(1,r/2);
            break;
          case 2:
            on=abs(x)+abs(y)<=r&&abs(z)<=max(1,r/2)&&
               (abs(x)+abs(y)>=r-1||abs(z)==max(1,r/2));
            break;
          case 3:
            on=max(abs(x),abs(z))==r||abs(y)==max(1,r/2);
            break;
          case 4:
            on=abs(x)+abs(z)<=r&&
               (abs(x)+abs(z)>=r-1||abs(y)==max(1,r/2));
            break;
          case 5:
            on=max(abs(x),abs(z))+0.35f*min(abs(x),abs(z))>=r-1&&
               max(abs(x),abs(z))+0.35f*min(abs(x),abs(z))<=r;
            break;
          case 6:
            on=max(abs(x),abs(z))==r||abs(y)==max(1,r/2);
            break;
          case 7:
            on=abs(x)==r||abs(z)==r||y==-r||y==r-abs(z);
            break;
          case 8:
            on=abs(d-r)<=0.75f;
            break;
          case 9:
            on=y>=0&&abs(d-r)<=0.75f;
            break;
          case 10:
            on=abs(rad-r)<=0.75f||abs(y)==r;
            break;
          case 11:{
            float rr=r*((r-y)/(float)max(1,2*r));
            on=y>=-r&&y<=r&&(abs(rad-max(0,rr))<=0.8f||y==-r);
            break;
          }
          case 12:
            on=abs(sqrt(sq(rad-max(2,r*0.65f))+y*y)-max(1,r*0.3f))<=0.8f;
            break;
          case 13:{
            int half=max(0,r-(y+r));
            on=y>=-r&&y<=r&&(abs(x)==half||abs(z)==half||y==-r);
            break;
          }
          case 14:
            on=abs(x)+abs(y)+abs(z)<=r&&
               (abs(x)+abs(y)+abs(z)>=r-1||y==-r);
            break;
          case 15:
            on=abs(x)+abs(y)+abs(z)>=r-1&&
               abs(x)+abs(y)+abs(z)<=r+1;
            break;
        }

        if(on) setVoxel(cursorX+x,cursorY+y,cursorZ+z,c);
      }
    }
  }

  rebuildMultiplexList();
  resetMultiplex();
  setStatus("PLACED "+SHAPES[shapeIndex]);
}

void setStatus(String s){
  status=s;
  statusUntil=millis()+2000;
}

boolean inside(float px,float py,float x,float y,float w,float h){
  return px>=x&&px<=x+w&&py>=y&&py<=y+h;
}

/*
  CORRECTED FOR OLDER APDE/JAVA SOURCE LEVELS:
  Do not use switch(String) here.
*/
void setView(String v){
  autoRotate=false;
  autoRot=0;

  if(v.equals("ISO")){
    rotX=-0.615f;
    rotY=0.785f;
  }else if(v.equals("FRONT")){
    rotX=0;
    rotY=0;
  }else if(v.equals("BACK")){
    rotX=0;
    rotY=PI;
  }else if(v.equals("LEFT")){
    rotX=0;
    rotY=-HALF_PI;
  }else if(v.equals("RIGHT")){
    rotX=0;
    rotY=HALF_PI;
  }else if(v.equals("TOP")){
    rotX=-HALF_PI;
    rotY=0;
  }else if(v.equals("BOTTOM")){
    rotX=HALF_PI;
    rotY=0;
  }

  setStatus(v+" VIEW - ROTATION STOPPED");
}

void advanceScroll(){
  String all=inputText.toUpperCase().replace('\n',' ');
  if(all.length()==0) return;

  scrollOffset+=scrollRTL?-1:1;

  if(scrollOffset< -all.length()) scrollOffset=16;
  if(scrollOffset>all.length()) scrollOffset=-16;

  String padded="                "+all+"                ";
  int start=constrain(scrollOffset+16,0,max(0,padded.length()-1));
  String visible=padded.substring(start,min(padded.length(),start+3));

  if(visible.length()==0) visible=" ";

  allocateGrid(16,16,16);
  drawTextIntoGrid(visible,0);
  rebuildMultiplexList();
  resetMultiplex();
}

void openNativeTextDialog(){
  final String oldText=inputText;

  getActivity().runOnUiThread(new Runnable(){
    public void run(){
      final EditText edit=new EditText(getActivity());

      edit.setSingleLine(false);
      edit.setMinLines(1);
      edit.setMaxLines(3);
      edit.setText(oldText);
      edit.setSelection(edit.getText().length());

      edit.setInputType(
        InputType.TYPE_CLASS_TEXT|
        InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS|
        InputType.TYPE_TEXT_FLAG_MULTI_LINE
      );

      edit.setHint("Type text, then tap OK");

      final AlertDialog dialog=new AlertDialog.Builder(getActivity())
        .setTitle("GECKOCUBE TEXT")
        .setView(edit)
        .setPositiveButton("ENTER / BUILD",
          new DialogInterface.OnClickListener(){
            public void onClick(DialogInterface d,int which){
              inputText=edit.getText().toString().toUpperCase();

              if(inputText.length()>200){
                inputText=inputText.substring(0,200);
              }

              scrolling=false;
              activeEffect=-1;
              parseWords();
              wordIndex=0;
              mode=WORDS;
              buildCurrentWord();
              setStatus("TEXT ACCEPTED");
            }
          })
        .setNegativeButton("CANCEL",
          new DialogInterface.OnClickListener(){
            public void onClick(DialogInterface d,int which){
              setStatus("TEXT EDIT CANCELLED");
            }
          })
        .create();

      dialog.setOnShowListener(new DialogInterface.OnShowListener(){
        public void onShow(DialogInterface d){
          dialog.getWindow().setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
          );
          edit.requestFocus();
        }
      });

      dialog.show();

      dialog.getWindow().setSoftInputMode(
        WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
      );
    }
  });
}

void updateSlider(float px){
  speedSlider=constrain((px-64)/max(40,panelW-112)*100,0,100);
  if(mux) lastScanNanos=System.nanoTime();
}

void mousePressed(){
  lastX=mouseX;
  lastY=mouseY;

  if(inside(mouseX,mouseY,0,height-27,panelW,27)){
    muxSliderDragging=true;
    updateSlider(mouseX);
    return;
  }

  dragging=mouseX>=viewX&&mouseY>=viewY&&mouseY<height-bottomH;
  if(dragging) return;
}

void mouseDragged(){
  if(muxSliderDragging){
    updateSlider(mouseX);
    return;
  }

  if(!dragging) return;

  rotY+=(mouseX-lastX)*0.012f;
  rotX=constrain(rotX+(mouseY-lastY)*0.012f,-PI,PI);

  autoRotate=false;
  autoRot=0;

  lastX=mouseX;
  lastY=mouseY;
}

void mouseReleased(){
  if(muxSliderDragging){
    muxSliderDragging=false;
    return;
  }

  if(dragging){
    dragging=false;
    return;
  }

  handleTap(mouseX,mouseY);
}

void handleTap(float px,float py){
  float bw=max(60,min(94,width*0.095f));
  float bh=min(32,topH*0.58f);
  float by=(topH-bh)*0.5f;
  float bx=width-2*bw-22;

  if(inside(px,py,bx,by,bw,bh)){
    mode=WORDS;
    scrolling=false;
    parseWords();
    buildCurrentWord();
    return;
  }

  if(inside(px,py,bx+bw+7,by,bw,bh)){
    mode=SOLIDS;
    scrolling=false;
    allocateGrid(16,16,16);
    clearVoxelsSilently();
    resetMultiplex();
    return;
  }

  if(px>=viewX&&py>=viewY&&py<height-bottomH){
    float y=viewY+viewH-29;
    float g=3;
    float w=(viewW-16-g*8)/9;
    float x=viewX+8;

    String[] labels={
      "ISO","FRONT","BACK","LEFT","RIGHT","TOP","BOTTOM","STOP","AUTO"
    };

    for(int i=0;i<labels.length;i++){
      if(inside(px,py,x+i*(w+g),y,w,24)){
        if(i<7){
          setView(labels[i]);
        }else if(i==7){
          autoRotate=false;
          autoRot=0;
          setStatus("ROTATION STOPPED");
        }else{
          autoRotate=!autoRotate;
          setStatus(autoRotate?"AUTO ROTATION ON":"AUTO ROTATION OFF");
        }
        return;
      }
    }

    return;
  }

  if(py<height-bottomH||px>=panelW) return;

  if(inside(px,py,0,height-27,panelW,27)){
    updateSlider(px);
    return;
  }

  float x=9,g=5,aw=panelW-18,y=height-bottomH+7;

  if(mode==WORDS){
    y+=14+27+5;
    float bw2=(aw-3*g)/4;

    if(inside(px,py,x,y,bw2,25)){
      openNativeTextDialog();
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      parseWords();
      wordIndex=0;
      scrolling=false;
      activeEffect=-1;
      buildCurrentWord();
      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      previousWord();
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      nextWord();
      return;
    }

    y+=30;

    if(inside(px,py,x,y,bw2,25)){
      autoWords=!autoWords;
      wordAt=millis();
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      scrolling=!scrolling;

      if(scrolling){
        scrollSource=inputText;
        lastScrollAt=millis();
      }else{
        buildCurrentWord();
      }

      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      scrollRTL=!scrollRTL;
      setStatus(scrollRTL?"RIGHT TO LEFT":"LEFT TO RIGHT");
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      scrollSpeed=min(5,scrollSpeed+0.5f);
      return;
    }

    y+=30;

    if(inside(px,py,x,y,bw2,25)){
      activeEffect=(int)random(EFFECTS.length);
      effectStart=millis();
      setStatus("RANDOM FX: "+EFFECTS[activeEffect]);
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      activeEffect=-1;
      setStatus("TEXT EFFECT OFF");
      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      mux=!mux;
      resetMultiplex();
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      blink=!blink;
      return;
    }

    y+=30;

    if(inside(px,py,x,y,bw2,25)){
      zoom=max(0.55f,zoom-0.1f);
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      zoom=min(1.4f,zoom+0.1f);
      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      clearVoxels();
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      scrollSpeed=max(0.5f,scrollSpeed-0.5f);
      return;
    }

    y+=29;
    handlePaletteTap(px,py,x+38,y,min(24,(aw-45-7*4)/8),4);

  }else{
    y+=15;
    float bw2=(aw-3*g)/4;

    if(inside(px,py,x,y,bw2,25)){
      shapeIndex=(shapeIndex+SHAPES.length-1)%SHAPES.length;
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      shapeIndex=(shapeIndex+1)%SHAPES.length;
      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      placeShape();
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      clearVoxels();
      return;
    }

    y+=30;

    if(inside(px,py,x,y,bw2,25)){
      shapeSize=max(2,shapeSize-1);
      return;
    }

    if(inside(px,py,x+bw2+g,y,bw2,25)){
      shapeSize=min(14,shapeSize+1);
      return;
    }

    if(inside(px,py,x+2*(bw2+g),y,bw2,25)){
      int[] st={1,2,4,8};
      int k=0;

      while(k<st.length&&st[k]!=cursorStep) k++;

      cursorStep=st[(k+1)%st.length];
      return;
    }

    if(inside(px,py,x+3*(bw2+g),y,bw2,25)){
      mux=!mux;
      resetMultiplex();
      return;
    }

    y+=30;

    float cw=(aw-5*g)/6;

    for(int i=0;i<6;i++){
      if(inside(px,py,x+i*(cw+g),y,cw,24)){
        moveCursor(i/2,(i%2==0?-1:1)*cursorStep);
        return;
      }
    }

    y+=42;
    handlePaletteTap(px,py,x+38,y,min(24,(aw-45-7*4)/8),4);
  }
}

void handlePaletteTap(float px,float py,float startX,float y,
                      float sw,float gap){
  for(int i=0;i<COLORS.length;i++){
    float bx=startX+i*(sw+gap);

    if(inside(px,py,bx,y,sw,21)){
      colorIndex=i;

      if(mode==WORDS&&!scrolling){
        buildCurrentWord();
      }else if(mode==SOLIDS){
        setStatus(COLOR_NAMES[i]);
      }

      return;
    }
  }
}

void keyPressed(){
  if(key==ENTER||key==RETURN){
    if(mode==WORDS){
      parseWords();
      wordIndex=0;
      buildCurrentWord();
    }
    return;
  }

  if(key=='1'){
    mode=WORDS;
    parseWords();
    buildCurrentWord();
  }

  if(key=='2'){
    mode=SOLIDS;
    allocateGrid(16,16,16);
    clearVoxelsSilently();
  }

  if(key=='n'||key=='N') nextWord();
  if(key=='b'||key=='B') previousWord();
  if(key=='c'||key=='C') clearVoxels();

  if(key=='m'||key=='M'){
    mux=!mux;
    resetMultiplex();
  }

  if(key=='a'||key=='A') autoRotate=!autoRotate;
  if(key=='r'||key=='R') setView("ISO");

  if(key=='+'||key=='=') speedSlider=min(100,speedSlider+5);
  if(key=='-'||key=='_') speedSlider=max(0,speedSlider-5);

  if(mode==SOLIDS){
    if(key=='p'||key=='P') placeShape();
    if(key=='s'||key=='S') shapeIndex=(shapeIndex+1)%SHAPES.length;
  }
}
