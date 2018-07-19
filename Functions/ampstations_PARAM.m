% function made to output the list of stations to be output for amplitude 
% calculation, this is a very simple function but quite useful as it can be used
% a lot of times
% 
% Input:
%     mainfile: main parameter file for PSPicker (string)
%  
% Output:
%     stations_amp: stations that will be used for amplitude calculation (cellarray)
%     
% Example:
%     stations_amp=ampstations_PARAM('mainfile_Gorkha.txt')


function stations_amp=ampstations_PARAM(mainfile)

	PickerParam=readmain(mainfile);    

	stations=fieldnames(PickerParam.Station_param);
	stations_amp=stations;

	% As amp parameters in mainfile are depreaced, it is so here, too!
	%for i=1:numel(stations)
	%   if ~isempty(PickerParam.Station_param.(stations{i}).amp)
	%       stations_amp=[stations_amp;stations(i)];
	%   end
	%end

end