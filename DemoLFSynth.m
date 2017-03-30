% DemoLFSynth: This is a demonstration of LFSynth, a bare-bones light field renderer implemented in
% MATLAB.
% 
% The renderer deals only with flat, textured objects. Shapes are implemented through opacity or
% tiling in the texture bitmaps. Most functionality of a typical rendering tool are missing: it's
% only planes and textures. Limited transparency is allowed via the alpha channel of texture
% bitmaps, but multiple occluding transparent objects at different depths are not generally handled
% correctly.
% 
% Despite its limitations, this tool can create useful light fields with correct, depth-dependent
% geometry. The two included examples show how complex scenes can be constructed.
% 
% Options: All tuneable options are in the "options" section at the top of this file. Oversampling
% allows antialised output. Scene geometry and camera parameters are defined in the scene building
% files (SceneSnowflakes.m and SceneRobotsChecker.m). The camera's base pose is defined in the scene
% file, but can be modified via the CamPose vector. Depth-dependent light falloff is implemented
% outside the renderer, and demonstrates use of the depth information computed with the light field.
% 
% How it works: This demo first calls a scene-building script, SceneSnowflakes.m or
% SceneRobotsChecker.m, to populate a scene structure and describe the LF camera. Next it calls
% LFSynth to do the actual rendering, generating a light field.  Finally, it optionally saves the
% LF and thumbnail. The camera's intrinsic matrix is also computed.
% 
% Requires the Light Field Toolbox for MATLAB v0.4

% Copyright (c) 2017 Donald G. Dansereau

clearvars

%---Options-------------------------------------------------------------------------------------

% Change SceneBuildFunc to different scene-building functions
SceneBuildFunc = @(LFInfo) SceneRobotsChecker(LFInfo);
% e.g. try
% SceneBuildFunc = @(LFInfo) SceneSnowflakes(LFInfo);

% Camera's pose relative to base pose as defined in the scene file
% The pose is given as an x,y,z translation, then Rodrigues angles
CamPose = [0,0,0,0,0,0]; 

DoSave = true;                 % optionally save
OutputPath = '~/tmp/LFRender'; % where to save files

% Output size and rendering quality
DoPreviewMode = true;  % use lower-quality settings as defined below

LFInfo.Aspect = 4/3;    % output aspect ratio
LFInfo.BaseUVRes = 256; % LF resolution in u,v (subview pixels)
LFInfo.STRes = 13;      % LF resolution in s,t (camera poses)
LFInfo.OversampUV = 2;  % Oversample rate in u,v, used to anti-alias

% Preview mode: set DoPreviewMode = true above for a faster preview using the following settings:
if( DoPreviewMode )
	LFInfo.STRes = 3;
	LFInfo.BaseUVRes = 256;
	LFInfo.OversampUV = 1;
end

DoDepthFalloff = false;  % if true, things get darker with distance from camera
DepthFalloffPower = 0.2; % rate at which light dims with distance, try 2 for SceneRobotsChecker

RandSeed = 42;      % random number generator seed, for repeatable randomly generated scene content

%---End options-------------------------------------------------------------------------------------

%---Derived---
rng(RandSeed); % set the random number generator seed
RenderOptions.FindRayLen = DoDepthFalloff; % don't need ray lengths if not doing falloff

%---Build the scene, populating the shapes structure---
[Shapes, LFInfo] = SceneBuildFunc(LFInfo); 

% find the output resolution, incuding oversampling and aspect ratio
LFInfo.LFSize = round([LFInfo.STRes,LFInfo.STRes,LFInfo.BaseUVRes,LFInfo.Aspect*LFInfo.BaseUVRes]);
TargetSize = LFInfo.LFSize;
LFInfo.LFSize = LFInfo.LFSize.*[1,1,LFInfo.OversampUV.*[1,1]];

%--- Define the camera's pose ---
Rmotion = rodrigues( CamPose(4:6) );
Rbase = rodrigues( LFInfo.BasePose(4:6) );
R = Rbase * Rmotion;
SceneGeom.CamRot = rodrigues( R );
SceneGeom.CamPos = (Rbase*CamPose(1:3)')' + LFInfo.BasePose(1:3);

%--- Render ---
tic
[LF,LFInfo] = LFSynth( LFInfo, SceneGeom, Shapes, RenderOptions );
toc

%--- apply depth-dependent brightness falloff ---
if( DoDepthFalloff )
	% Z = LF(:,:,:,:,5); % depth along z
	D = LF(:,:,:,:,6);  % distance from camera

	for( iChan=1:3 )
		FallOff = 1 ./ D.^DepthFalloffPower;
		FallOff = FallOff ./ max(FallOff(:));
		LF(:,:,:,:,iChan) = LF(:,:,:,:,iChan) .* FallOff;
	end
	clear D Z Falloff
end
LF = LF(:,:,:,:,1:3); % strip depth and alpha
	
%--- de-oversamp by scaling the rendered images down in u,v ---
if( LFInfo.OversampUV > 1 )
	for(TIdx = 1:size(LF,1))
		for(SIdx = 1:size(LF,1))
			LF2(TIdx,SIdx,:,:,:) = imresize(squeeze(LF(TIdx,SIdx,:,:,:)), TargetSize(3:4));
		end
	end
	LF = LF2;
	clear LF2

	% redo intrinsics for new size
	LFInfo.LFSize = size(LF(:,:,:,:,1));
	LFInfo.CamIntrinsicsAbsH = BuildIntrinsicsFromLFInfo(LFInfo);
end
 
%--- convert to int ---
LF = cast(LF.*255, 'uint8');

%--- interactive display ---
InteractiveViewMagnification = 2;
LFDispMousePan(LF, InteractiveViewMagnification);

%--- save ---
if( DoSave )
	OutFname = fullfile(OutputPath, sprintf('%s-%d-%d-%g-%g-o%d.mat', LFInfo.SceneName, LFInfo.STRes, LFInfo.BaseUVRes, LFInfo.STExtent(1), LFInfo.UVExtent(1), LFInfo.OversampUV));
	TimeStamp = datestr(now,'ddmmmyyyy_HHMMSS');
	GeneratedByInfo = struct('mfilename', mfilename, 'time', TimeStamp, 'VersionStr', LFSynthVersion );
	save(OutFname,'LF','LFInfo','GeneratedByInfo');
	a = LFDisp(LF);
	imwrite(a,[OutFname(1:end-3),'png']);
end