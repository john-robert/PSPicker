% Function made to compute the amplitude associated to picks.
% The function requires a location and theoretical arrival times because we pick
% the amplitudes on theoretical arrivals.
% The input of the function is an EVENT structure
% First the function will convert velocities to disp('Text');lacements (Poles and zeros file needed)
% then we'll take windows around arrivals to get the amplitude, several amplitudes for a same
% station and channel can be computed, an amplitude is necessarly linked a phase (P,S, Pn..) to form a pair
% The Output is an event structure

% Input:
%     - IN: EVENT structure containing picks with theoretical arrival times
%     - mainfile: parameter file
%     - PZ_file: file with gains, poles and zeros associated to station
%     - flag_plot
%     
% Output:
%     - Out: Event structure with amplitudes

% clear all
% close all
% 
% %%% Load data structure
% 
% S=load('S1.mat');
% S=S.S1;


function S=amp_EVENT(EVENT,mainfile,pz_file,flag_plot)


    %%% Parameters
    window = [5 5];     % Time to get the amp % Time to get the amp in seconds
    units  = 'nm';
    coef   = 0.2;


    %%%% Must add the computation of the theoretcial times
    %fprintf(1,'Don''t forget to compute the theoretical arrival times first ');


    %%% Read main file
    PickerParam    = readmain(mainfile);    


    %%% Get hypocenter path
    hyp            = PickerParam.hyp;


    %%% Method amplitude picking: 'maxi' or 'pk2pk'
    amp_method     = PickerParam.amp_method;


    %%% Select stations to be processed for amplitudes
    stations_input = ampstations_PARAM(mainfile);


    %%% Rearrange EVENT so that we only have travel times for selected station
    EVENT.PHASES   = get_PHASE(EVENT.PHASES,'station',stations_input);


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Get DATA associated to EVENT 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%
    %%% Extract MSEED %%%
    %%%%%%%%%%%%%%%%%%%%%

    stations_str = strjoin(stations_input);
    channel_sel  = {};
    
    for i=1:numel(stations_input)
        pick_struct=PickerParam.Station_param.(stations_input{i}).pick;
        fsc=fieldnames(pick_struct);
        for j=1:numel(fsc)
            channel_scra = pick_struct.(fsc{j}).channelID;
            channel_sel  = [channel_sel channel_scra];
        end
    end
    
    channel_sel    = unique(channel_sel);
    channel_str    = strjoin(channel_sel);

    %%% Select time only for stations in PickerParam
    delay_before   = PickerParam.extract_time(1);
    delay_after    = PickerParam.extract_time(2);

    start_time     = min([EVENT.PHASES.THEO])-delay_before/86400;
    end_time       = max([EVENT.PHASES.THEO])+delay_after/86400;
    
    start_time_str = datestr(start_time, 'yyyy-mm-dd HH:MM:SS');
    end_time_str   = datestr(end_time,   'yyyy-mm-dd HH:MM:SS');


    locate_sds     = which('sds2mseed.sh');
    output_mseed   = './tmp/cat.mseed';
    cmd            = sprintf('-start "%s" -end "%s" -sta "%s" -comp "%s" -sds "%s" -o "%s"', start_time_str,end_time_str,stations_str,channel_str,PickerParam.sds_path,output_mseed);
    
    [~,b]          = system([locate_sds,' ',cmd]);
    
    if regexp(b,'dataselect command not found')
        error('dataselect not here');
        return;
    end


    %%%%%%%%%%%%%%%%%%
    %%% Read file %%%%
    %%%%%%%%%%%%%%%%%%
    
    X        = rdmseed(output_mseed);
    S        = get_DATA(X);
    S.EVENTS = EVENT;
    clear X
    delete(output_mseed);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    %%%% Put the PZ info into the data structure and compute DISP
    S       = compute_DISP(S,pz_file,mainfile);


    %%%% Loop over the stations present in mainfile
    EVENTS  = S.EVENTS;
    DATA    = S.DATA;
    PHASES  = EVENTS.PHASES;


    %%% Update phase fields and inialize all write_flag to 1
    PHASE_REF              = init_PHASE(1);
    PHASES                 = update_fields(PHASES,PHASE_REF);
    [PHASES(:).WRITE_FLAG] = deal(1);
    S.EVENTS.PHASES        = PHASES;


    %%% Start loop
    for iter=1:length(DATA)

        close all
        
        station = DATA(iter).STAT;
        rsample = DATA(iter).RSAMPLE;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Reject stations not listed for picking in mainfile.txt %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if ~any(strcmp(strtrim(station),stations_input)) || isempty(PickerParam.Station_param.(station).amp)
            continue
        end

        %%% Check if station contains DISP data
        if isempty({DATA(iter).RAW(:).DISP})
            continue
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Go through all requested arrivals (around P, Pn , Sn...)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        phase_select=fieldnames(PickerParam.Station_param.(station).amp);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Build search windows %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        for j = 1:numel(phase_select)
            phase=phase_select{j};
            
            %%% Find the theo time for the selected phase and station
            [OUT,ind_select]=get_PHASE(PHASES,'station',station,'type',phase);
            if isempty(ind_select)
                continue
            elseif length(ind_select)>1
                fprintf(1,'WARNING: station %s has more than one %s phase\n',station,phase);
                continue
            end
            
            time_phase=PHASES(ind_select).THEO;
            PHASES(ind_select).AMP_WINDOW = ...
                [time_phase-window(1)/86400 ...
                time_phase+window(2)/86400];
        end

        %%% Recompute search windows so that there is no overlap
        PHASES=adapt_WIN(PHASES,'station',station,'coef',coef);


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Re-loop to get amplitudes %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%% Get amplitudes, time and windows for all requested phases;
        for j = 1:numel(phase_select)
            phase=phase_select{j};

            %%% Find the theo time for the selected phase and station
            [OUT,ind_select] = get_PHASE(PHASES,'station',station,'type',phase);
            time_phase       = PHASES(ind_select).THEO;

            channelID        = PickerParam.Station_param.(station).amp.(phase).channelID;
            DATA_amp         = select_DATA(DATA(iter),station,'channelID',channelID);

            if isempty({DATA_amp.RAW(:).DISP})
                continue
            end


            %%%% Check if channels pass SNR test
            window_snr                 = [2 3];
            SNR_PARAM                  = init_SNRTEST();
            SNR_PARAM.time_phase       = time_phase;
            SNR_PARAM.filter_band      = [1 10];
            SNR_PARAM.window           = window_snr;
            SNR_PARAM.threshold        = 1.5;
            SNR_PARAM.LTA              = 3;
            SNR_PARAM.STA              = 1;
            
            [boolean_test,max_snr,SNR] = pass_SNRTEST(DATA_amp,SNR_PARAM,flag_plot);
            a                          = cat(2,DATA_amp.RAW(:).DISP);

            if ~any(boolean_test)
                fprintf(1, '   amplitude picking: phase "%s" (stat "%s") did not pass SNR test.\n', phase, station )
                %fprintf(1. '                      (f=%s-%s Hz, SNR_thres=%5.2f, LTA_wind=%4.1f, STA_wind=%4.1f). Skipped.\n', SNR_PARAM.filter_band(1), SNR_PARAM.filter_band(2), SNR_PARAM.threshold, SNR_PARAM.LTA, SNR_PARAM.STA)
                continue
            else
                DATA_amp.RAW=DATA_amp.RAW(boolean_test);
            end


            %%%% Start picking amplitude
            displa   = DATA_amp.RAW.DISP;
            t_begin  = DATA_amp.RAW.TIMESTART;
            rsample  = DATA_amp.RSAMPLE;
            A        = pick_AMP(displa, PHASES(ind_select).AMP_WINDOW, t_begin, rsample, units, amp_method, flag_plot);

            PHASES(ind_select).PERIOD      = A.PERIOD;
            PHASES(ind_select).AMP         = A.AMP;
            PHASES(ind_select).AMP_ARRIVAL = A.TIME;
        end
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Compute magnitudes %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    [PHASES,mag_old] = mag_PHASES(PHASES,'STATION0.HYP');


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Clean mag PHASE %%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    [PHASES,mag]     = cleanmag_PHASES(PHASES,1,flag_plot );

    %%% Plot if asked
    if flag_plot
        plotmag_PHASES(PHASES);
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% Don't compute mag if less than k amplitudes
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    ind_select    = (~cellfun(@isempty,{PHASES.MAG}) & cellfun(@(x) x==1,{PHASES.WRITE_FLAG}));
    num_valid_pha = sum(ind_select);
    if num_valid_pha < PickerParam.minphase_amp
        mag = [];
        [PHASES(ind_select).WRITE_FLAG]=deal(0);
    end

    if flag_plot
        plotmag_PHASES(PHASES);
    end

    %%%%%% Write final mag %%%%
    EVENTS.MAG    = mag;
    EVENTS.PHASES = PHASES;

    NEW_EVENT     = EVENTS;
    S.EVENTS      = NEW_EVENT;
    S.DATA        = DATA;

end




