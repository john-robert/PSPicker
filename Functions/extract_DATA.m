% Function made to extract the MSEED from an event and an SDS archive
% 
% Input:
%     EVENT: event structure
%     mainfile: picking mainfile
% 
% Ouptut:
%     DATA
%     S


function [DATA,S]=extract_DATA(EVENT,mainfile,debug)


    %%% Get path and parameters
    PickerParam    = readmain(mainfile);
    
    hyp            = PickerParam.hyp;
    delay_before   = PickerParam.extract_time(1);
    delay_after    = PickerParam.extract_time(2);
    output_mseed   = './tmp/cat.mseed';
    DATA           = [];
    S              = [];


    %%% Get List of stations to be processed from mainfile
    stations       = fieldnames(PickerParam.Station_param);
    stations_str   = strjoin(stations);
    channels       = chanlist_PARAM(PickerParam);
    channels_str   = strjoin(channels);


    %%% Compute theo
    EVENT          = comp_THEO(PickerParam,hyp,EVENT,debug);


    %%% Only get stations referenced in Parameter file
    EVENT.PHASES   = get_PHASE(EVENT.PHASES,'station',stations);


    %%%%%%%%%%%%%%%%%%%%%
    %%% Extract mseed %%%
    %%%%%%%%%%%%%%%%%%%%%

    start_time     = min([EVENT.PHASES.THEO])-delay_before/86400;
    end_time       = max([EVENT.PHASES.THEO])+delay_after/86400;
    start_time_str = datestr(start_time, 'yyyy-mm-dd HH:MM:SS');
    end_time_str   = datestr(end_time, 'yyyy-mm-dd HH:MM:SS');    

    locate_sds     = which('sds2mseed.sh');
    cmd            = sprintf('-start "%s" -end "%s" -sta "%s" -comp "%s" -sds "%s" -o "%s"', start_time_str,end_time_str,stations_str,channels_str,PickerParam.sds_path,output_mseed);

    % call sds2mseed.sh script that uses IRIS' "dataselect" tool. 
    % this call creates a file "data_used.file" in pwd that lists waveform data used (or rather match some time creteria, specific files (e.g. when hour files) might not be used)
    % "data_used.file" is then not further used and put into tmp folder
    [error_flag,~] = system([locate_sds,' ',cmd]);
    %disp([locate_sds,' ',cmd]);
    if error_flag
       fprintf(1,'No data found in %s for %s <= time < %s\n',PickerParam.sds_path, start_time_str, end_time_str);
       return;
    end
    movefile('data_used.file', './tmp/data_used.file');


    %%%%%%%%%%%%%%%%%%
    %%% Read file %%%%
    %%%%%%%%%%%%%%%%%%

    X        = rdmseed(output_mseed);
    S        = get_DATA(X);
    DATA     = S.DATA;
    S.EVENTS = EVENT;

end

