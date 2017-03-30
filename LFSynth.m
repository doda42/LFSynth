% LFSynth.m: Render a light field based on a scene and camera description.
% 
% This is part of LFSynth, a bare-bones light field renderer implemented in MATLAB.
% 
% The output LF has 5 or 6 channels.  The first 3 are rgb, then alpha(4), depth along z(5), and
% optionally, for RenderOptions.FindRayLen enabled, distance to scene along ray(6).
% 
% Please see DemoLFSynth.m for further information.

% Copyright (c) 2017 Donald G. Dansereau

function [LF,LFInfo] = LFSynth( LFInfo, SceneGeom, Shapes, RenderOptions )

%---Defaults---
LFInfo = LFDefaultField( 'LFInfo', 'LFSize', [16,16,128,128]);  % number of samples
LFInfo = LFDefaultField( 'LFInfo', 'STExtent', [0.25,0.25]);    % camera's "baseline" (st extent)
LFInfo = LFDefaultField( 'LFInfo', 'D', 3);                     % distance to u,v plane
LFInfo = LFDefaultField( 'LFInfo', 'UVExtent', LFInfo.D/3);     % camera's FOV (uv extent)
SceneGeom = LFDefaultField( 'SceneGeom', 'CamRot', [0,0,0] );   % camera's rotation

RenderOptions = LFDefaultField( 'RenderOptions', 'FindRayLen', false ); % find per-ray dist to camera
RenderOptions = LFDefaultField( 'RenderOptions', 'Precision', 'single' );

%---Derived---
if( numel(LFInfo.UVExtent) == 1 )
	LFInfo.UVExtent = LFInfo.UVExtent .* [1,1];
end
if( RenderOptions.FindRayLen )
	ColChans = [1:3, 5,6];
else
	ColChans = [1:3, 5];
end
NChans = 1 + length(ColChans);

%--- Find camera intrinsics ---
LFInfo.CamIntrinsicsAbsH = BuildIntrinsicsFromLFInfo(LFInfo);

%--- Setup cam ---
TVec = linspace(-LFInfo.STExtent(2)/2,LFInfo.STExtent(2)/2, LFInfo.LFSize(1));

%--- Build LF---
LF = zeros([LFInfo.LFSize,NChans], RenderOptions.Precision);
for( TIdx = 1:length(TVec) )
	fprintf('.');
	
	LFSlice = zeros([LFInfo.LFSize(2:end),NChans], RenderOptions.Precision);
	LFSlice(:,:,:,5) = 1e9; % init depth to "far"
	
 	% build up the rays we want to sample
	[ss,tt,uu,vv] = BuildRaysForCamera( LFInfo, TIdx, RenderOptions );

	% break into ray position and normalized direction
	RayPos = [ss(:), tt(:), zeros(size(ss(:)))];
	RayDir = [uu(:)-ss(:), vv(:)-tt(:), LFInfo.D.*ones(size(ss(:)))] / LFInfo.D;
	RayDirL = sqrt(sum(RayDir'.^2))';
	RayDir = bsxfun(@rdivide, RayDir,RayDirL);
	clear RayDirL
	
	% apply camera pose
	CamRot = cast(rodrigues( SceneGeom.CamRot ), RenderOptions.Precision);
	RayPos = (CamRot * RayPos')';
	RayDir = (CamRot * RayDir')';
	RayPos = bsxfun(@plus, RayPos, SceneGeom.CamPos);
	
	%--- Iterate through shapes ---
	for( iCurShape = 1:length(Shapes) )
		CurShape = Shapes(iCurShape);
		if( isfield(CurShape, 'Disable') && ~isempty(CurShape.Disable) && CurShape.Disable )
			continue;
		end
		
		% each shape gets rendered into an LF, then the LF is merged into the full render
		CurLF = zeros([LFInfo.LFSize(2:end),NChans], RenderOptions.Precision);
		
		% define coordinate system local to the current shape
		% make sure up and normal are orthogonal
		CurShape.PlaneN = CurShape.PlaneN ./ norm(CurShape.PlaneN);
		UpDotN = dot(CurShape.PlaneUp, CurShape.PlaneN);
		CurShape.PlaneUp = CurShape.PlaneUp - UpDotN*CurShape.PlaneN;
		CurShape.PlaneUp = CurShape.PlaneUp ./ norm(CurShape.PlaneUp);
		% now find right vector
		CurShape.PlaneR = cross( CurShape.PlaneUp, CurShape.PlaneN );
		CurShape.PlaneR = CurShape.PlaneR ./ norm(CurShape.PlaneR); % redundant
		
		% PInt = dist to shape
		Den = RayDir*CurShape.PlaneN';
		PInt = bsxfun(@minus, CurShape.PlanePos, RayPos);
		PInt = PInt * CurShape.PlaneN';
		PInt = PInt ./ Den;
		InvalidIdx = find(Den<=0);
		PInt(InvalidIdx) = NaN;
		clear Den
		
		% PInt = pt of intersection with shape
		PInt = bsxfun(@times, PInt, RayDir);
		PInt = bsxfun(@plus, PInt, RayPos);
		InvalidIdx = find(PInt(:,3)<0);
		PInt(InvalidIdx,:) = NaN;
		
		% PTex = where the ray indexes into the texture on the shape
		PTex = bsxfun(@minus, PInt, CurShape.PlanePos);
		PTexR = PTex*CurShape.PlaneR';  % dot prod
		PTexU = PTex*CurShape.PlaneUp';
		clear PTex

		% optionally scale the texture
		if( isfield(CurShape.Texture, 'Scale') )
			PTexU = PTexU ./ CurShape.Texture.Scale;
			PTexR = PTexR ./ CurShape.Texture.Scale;
		end
		
		% optionally tile the texture
		if( isfield(CurShape.Texture, 'Tile') && CurShape.Texture.Tile )
			PTexU = mod(PTexU+0.5,1)-0.5;
			PTexR = mod(PTexR+0.5,1)-0.5;
		end

		% define bitmap coordinates
		MBitmapSize = size(CurShape.Texture.Bitmap);
		MBitmapAspect = MBitmapSize(2)/MBitmapSize(1);
		CurShape.Texture.Bitmap = LFConvertToFloat( CurShape.Texture.Bitmap, RenderOptions.Precision );
		y = linspace(-0.5,0.5, MBitmapSize(1));
		x = linspace(-0.5,0.5, MBitmapSize(2)) .* MBitmapAspect;
		[xx,yy] = ndgrid( cast(y,RenderOptions.Precision), cast(x,RenderOptions.Precision) );
		
		% interpolate from bitmap at PTex location, i.e. where the ray intersects the shape
		NTexChans = size(CurShape.Texture.Bitmap,3);
		for( iColChan = 1:NTexChans )
			CurVal = interpn(xx,yy, CurShape.Texture.Bitmap(:,:,iColChan), PTexU, PTexR);
			CurLF(:,:,:,iColChan) = reshape(CurVal, LFInfo.LFSize(2:end));
		end
		if( NTexChans < 4 )
			CurLF(:,:,:,4) = 1;
		end
		
		CurLF(:,:,:,5) = reshape(PInt(:,3), LFInfo.LFSize(2:end));  % depth channel
		
		% optionally find distance along ray to shape
		if( RenderOptions.FindRayLen )
			PInt = bsxfun(@minus, PInt, RayPos);
			PInt = sqrt(sum(PInt.^2,2));
			CurLF(:,:,:,6) = reshape(PInt, LFInfo.LFSize(2:end));  % ray len
		end
		
		% merge current shape render with full render based on depth channel
		CloserIdx = cast(find(CurLF(:,:,:,5) < LFSlice(:,:,:,5)),'uint32');
		IdxPerChan = prod(LFInfo.LFSize(2:end));
		NewAlpha = CurLF(CloserIdx + (4-1)*IdxPerChan); % alpha of newly rendered object
		NewAlpha(isnan(NewAlpha)) = 0;
		for( iColChan = ColChans )
			PrevVal = LFSlice(CloserIdx + (iColChan-1)*IdxPerChan);
			NewVal = CurLF(CloserIdx + (iColChan-1)*IdxPerChan);
			NewVal(isnan(NewVal)) = 0;
			% this blending doesn't deal well with multiple transparent objects, as depth ordering
			% is not applied correctly
			MixedVal = (1-NewAlpha).*PrevVal + NewAlpha.*NewVal; 
			LFSlice(CloserIdx + (iColChan-1)*IdxPerChan) = MixedVal;
		end
	end
	
	LF(TIdx,:,:,:,:) = LFSlice;
	
	LFFigure(1);
	LFDisp(LF(TIdx,ceil(end/2),:,:,1:3));
	axis image
	title('...rendering...');
	drawnow
end

LFFigure(1);
title('Done');

end

%---Build up the rays we want to sample based on camera description---
function [ss,tt,uu,vv] = BuildRaysForCamera( LFInfo, TIdx, RenderOptions )
% start with index n = i,j,k,l
[jj,ii,ll,kk] = ndgrid(cast(TIdx,RenderOptions.Precision), cast(1:LFInfo.LFSize(2),RenderOptions.Precision), cast(1:LFInfo.LFSize(3),RenderOptions.Precision), cast(1:LFInfo.LFSize(4),RenderOptions.Precision));
N = [ii(:),jj(:),kk(:),ll(:),ones(size(ii(:)))]';
% now convert to ray via intrinsic matrix
P = LFInfo.CamIntrinsicsAbsH*N;
% extract components
ss = P(1,:);
tt = P(2,:);
uu = P(3,:);
vv = P(4,:);
end
