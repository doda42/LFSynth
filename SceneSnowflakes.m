% SceneSnowflakes: Build a scene to be rendered by LFSynth.
% 
% This is part of LFSynth, a bare-bones light field renderer implemented in MATLAB.
% 
% Please see DemoLFSynth.m for further information.

% Copyright (c) 2017 Donald G. Dansereau

function [Shapes, LFInfo] = SceneSnowflakes(LFInfo)

LFInfo.SceneName = mfilename();

LFInfo.BasePose = [0, 0.2, 0, 0, 0, 0]; % camera pose: x,y,z, Rodrigues angles

LFInfo.STExtent = 0.075.*[1,1]; % camera 'baseline', i.e. st plane extent
LFInfo.D = 3; % uv plane depth
LFInfo.UVExtent = LFInfo.D/3 .* [LFInfo.Aspect,1]; % camera FOV, i.e. uv plane extent

%---Load up the textures---
[tflakeSM,~,alpha] = imread('Textures/snow_circle.png');
tflakeSM(:,:,4) = alpha;

[ttree,~,alpha] = imread('Textures/trees-576573_960_720.png');
ttree(:,:,4) = alpha;

tback = imread('Textures/snow-landscape-mountains-nature.jpeg');

N = 1; % track objects as we add them

%---background---
Shapes(N).Texture.Bitmap = tback;
Shapes(N).Texture.Scale = 27;
Shapes(N).Texture.Tile = false;
Shapes(N).PlanePos = [0, -3, 75];
Shapes(N).PlaneN = [0, 0, 1];  % background points towards camera
Shapes(N).PlaneUp = [0, 1, 0]; % 'up' vector defines the texture orientation, must point along plane
N = N + 1;

%---trees---
Shapes(N).Texture.Bitmap = ttree;
Shapes(N).Texture.Scale = 5;
Shapes(N).PlanePos = [-1.5, 2.2, 20];
Shapes(N).Texture.Scale = 3;
Shapes(N).PlanePos = [0, 1.2, 8];
Shapes(N).PlaneN = [0, 0, 1];
Shapes(N).PlaneUp = [0, 1, 0];
N = N + 1;

Shapes(N).Texture.Bitmap = ttree(:,end:-1:1,:).*1.5; % brighter in foreground
Shapes(N).Texture.Scale = 1.5;
Shapes(N).PlanePos = [0, 0.9, 4];
Shapes(N).PlaneN = [0, 0, 1];
Shapes(N).PlaneUp = [0, 1, 0];
N = N + 1;

%---snowflakes---
FlakePos = -(rand(40,3)-0.5);  % random 3d positions
% but clipped in z direction to avoid blocking camera
FlakePos(:,3) = (FlakePos(:,3)+0.6)*20;
% and frustum-conforming to avoid making snowflakes that are entirely out of shot
FlakePos(:,2) = LFInfo.BasePose(2)+ FlakePos(:,2) .* (FlakePos(:,3)./3); 
FlakePos(:,1) = LFInfo.BasePose(1)+ FlakePos(:,1) .* (FlakePos(:,3)./3);
 
for( iShape = 1:size(FlakePos,1) )
	Shapes(N).Texture.Bitmap = tflakeSM;
	Shapes(N).Texture.Scale = 0.05;
	Shapes(N).PlanePos = FlakePos(iShape,:);
	Shapes(N).PlaneN = [0, 0, 1];
	Shapes(N).PlaneUp = [0, 1, 0];
	N = N + 1;
end