% SceneRobotsChecker.m: Build a scene to be rendered by LFSynth.
% 
% This is part of LFSynth, a bare-bones light field renderer implemented in MATLAB.
% 
% Please see DemoLFSynth.m for further information.

% Copyright (c) 2017 Donald G. Dansereau

function [Shapes, LFInfo] = SceneRobotsChecker(LFInfo)

LFInfo.SceneName = mfilename();

LFInfo.BasePose = [-0.07, 0, 0, -pi/17, 0, 0]; % camera pose: x,y,z, Rodrigues angles

LFInfo.STExtent = 0.075.*[1,1]; % camera 'baseline', i.e. st plane extent
LFInfo.D = 3; % uv plane depth
LFInfo.UVExtent = LFInfo.D/3 .* [LFInfo.Aspect,1]; % camera FOV, i.e. uv plane extent

FloorDist = 0.7; % this scene is shifted down along the y axis by this amount

%---Load up the textures---
[trobo,~,alpha] = imread('Textures/RobotClip.png');
trobo(:,:,4) = alpha;
[troboM,~,alpha] = imread('Textures/RobotClipM.png');
troboM(:,:,4) = alpha;
tfloor = imread('Textures/checkerboard.png');
twall = imread('Textures/checkerboard.png');

%--- filter textures ---
% To reduce aliasing filter your textures -- uncomment the following for a demo
% hrobo = fspecial('gaussian', 33, 2 * 256/(LFInfo.BaseUVRes*LFInfo.OversampUV));
% troboM = imfilter(troboM, hrobo);
% trobo = imfilter(trobo,hrobo);

N = 1; % track objects as we add them

%---floor---
Shapes(N).Texture.Bitmap = tfloor;
Shapes(N).Texture.Scale = 1.5;
Shapes(N).Texture.Tile = true;
Shapes(N).PlanePos = [0, FloorDist, 0.2];
Shapes(N).PlaneN = [0, 1, 0]; % floor normal points up
Shapes(N).PlaneUp = [0, 0, 1]; % 'up' vector defines the texture orientation, must point along plane
N = N + 1;

%---back wall---
Shapes(N).Texture.Bitmap = twall;
Shapes(N).Texture.Scale = 1.5;
Shapes(N).Texture.Tile = true;
Shapes(N).PlanePos = [0, 0, 5];
Shapes(N).PlaneN = [0, 0, 1]; % back wall points towards camera
Shapes(N).PlaneUp = [0, 1, 0];
N = N + 1;

%---Robots---
Shapes(N).Texture.Bitmap = trobo;
Shapes(N).Texture.Scale = 0.44;
Shapes(N).PlanePos = [-0.3, FloorDist - Shapes(N).Texture.Scale/2, 2.25];
Shapes(N).PlaneN = [0, 0, 1]; % robots point towards camera
Shapes(N).PlaneUp = [0, 1, 0];     % and are upright; the 
N = N + 1;

Shapes(N).Texture.Bitmap = trobo(:,end:-1:1,:);
Shapes(N).Texture.Scale = 0.44;
Shapes(N).PlanePos = [0, FloorDist - Shapes(N).Texture.Scale/2, 3];
Shapes(N).PlaneN = [0, 0, 1];
Shapes(N).PlaneUp = [0, 1, 0];
N = N + 1;

Shapes(N).Texture.Bitmap = troboM;
Shapes(N).Texture.Scale = 0.44;
Shapes(N).PlanePos = [0.4, FloorDist - Shapes(N).Texture.Scale/2, 3.7];
Shapes(N).PlaneN = [0, 0, 1];
Shapes(N).PlaneUp = [0, 1, 0];
N = N + 1;
