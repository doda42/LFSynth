% BuildIntrinsicsFromLFInfo.m: Build intrinsic matrix from camera array description
% 
% This is part of LFSynth, a bare-bones light field renderer implemented in MATLAB.
% 
% The intrinsic matrix is in the absolute 2-plane parameterization with 1-based indexing
% 
% Please see DemoLFSynth.m for further information.

% Copyright (c) 2017 Donald G. Dansereau

function AbsRectH = BuildIntrinsicsFromLFInfo(LFInfo)

tj_slope = LFInfo.STExtent(2)/(LFInfo.LFSize(1)-1);
si_slope = LFInfo.STExtent(1)/(LFInfo.LFSize(2)-1);
vl_slope = LFInfo.UVExtent(2)/(LFInfo.LFSize(3)-1);
uk_slope = LFInfo.UVExtent(1)/(LFInfo.LFSize(4)-1);

AbsRectH = [...
	si_slope, 0, 0, 0,        -LFInfo.STExtent(1)/2-si_slope;...
	0, tj_slope, 0, 0,        -LFInfo.STExtent(2)/2-tj_slope;...
	0, 0,        uk_slope, 0, -LFInfo.UVExtent(1)/2-uk_slope;...
	0, 0,        0, vl_slope, -LFInfo.UVExtent(2)/2-vl_slope;...
	0, 0,        0, 0,        1 ];

