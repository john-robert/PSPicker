%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                                                            %%
%%   ------------------------------------------------------   %%
%%   MAIN  FUNCTION  TO  COMPUTE  PICKS  AND  AMPLITUDES !!   %%
%%   ------------------------------------------------------   %%
%%                                                            %%
%%                                                            %%
%%   Start this script via Matlab, which has to be opened     %%
%%   from terminal (so environment variables are loaded),     %%
%%   from path where this file is located!!!                  %%
%%                                                            %%
%%   As for parameters, just look at 'mainfile.txt'.          %%
%%   Some further parameters are given in the befinning       %%
%%   of this file.                                            %%
%%                                                            %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%% Initiation 
clear 'main.m'
clear all
close all
fclose('all');

addpath(genpath('./Functions'));				% Load Paths to functions


%%% Parameters
mainfile  = {'./input_files/mainfile.txt'};		% can have multiple mainfiles to run mutliple serttings at once
log_file  = './tmp/log_file.txt';				% log_file name, better leave it like that (might be hard coded some place)
rms_thres = 4;									% threshold over which weight is set to 4 (means 0%) - used in script: rmres_EVENT.m
mstan     = 2;									% parameter that allows to customize removal of phases that distrub location - used in script: rmsta_EVENT.m
limit_pha = 4;									% parameter that allows to customize removal of phases that distrub location - used in script: rmsta_EVENT.m
limit_dev = 0.5;								% parameter that allows to customize removal of phases that distrub location - used in script: rmsta_EVENT.m
plot_save = 0;									% if set to 1, data are plotted and stored in results
flag_plot = 0;									% TO BE EDITTED AND IMPROVED !!
debug     = 0;									% TO BE EDITTED AND IMPROVED !!


%%% Get parameters / input_files from 'mainfile'
global PickerParam
[PickerParam,flag_path] = readmain(mainfile{1}); 
if flag_path==0
    return;
end
pz_file          = PickerParam.station_PZ;
input_nordic     = PickerParam.input_nordic;
results_folder   = PickerParam.results_folder;
reporting_agency = PickerParam.reporting_agency;


%%% Check if input is file or directory and store in cell
if exist(input_nordic)==2 % file
    files_nor  = {input_nordic};
elseif exist(input_nordic)==7 % directory
    files_nor  = dir( fullfile([input_nordic,'*.nor']));
    files_nor  = cellfun(@(x) [input_nordic,x],{files_nor.name},'UniformOutput',false);
end


%%% tmp directory for all tmp files (create if it doesn't exist, empty it if not empty)
path_tmp = [pwd, '/', 'tmp'];

if ~exist(path_tmp,'dir')
    mkdir(path_tmp)
elseif ~isempty(path_tmp)
    delete([path_tmp, '/*'])
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Loop over events of nordic file %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:numel(files_nor)


    %%% Read events
    filenor = files_nor{i};
    EVENTS  = nor2event(filenor);


    %%%% Start loop over events %%%%
    for j=1:numel(EVENTS)


    	% set reporting agency if was set to something in 'mainfile'
    	if ~isempty(reporting_agency)
    	    EVENTS(j).AGENCY = reporting_agency;
    	end



        fac = fopen(log_file,'at');
        clearvars -except ME mainfile fac files_nor i j pz_file results_folder reporting_agency path_tmp rms_thres mstan limit_pha limit_dev plot_save flag_plot debug EVENTS log_file


        %%% Message
        fprintf(1,  'Processing EVENT %s\n',EVENTS(j).ID);
        fprintf(fac,'Processing EVENT %s\n',EVENTS(j).ID);

        try

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% (1) Initial cleaning and relocation of events %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


            %%% mention it
            fprintf(1,   'Step 1: initial cleaning and relocation of event\n');
            fprintf(fac, 'Step 1: initial cleaning and relocation of event\n');


            EVENT=EVENTS(j);

            %%% Check if we have primer location
            if isempty(EVENT.LON)
                continue
            end


            %%% Readmain
            PickerParam        = readmain(mainfile{1}); 
            hyp                = PickerParam.hyp;


            %%% 1) Apply weight of 2 on all S by default
            [~,ind_S]          = get_PHASE(EVENT.PHASES,'type','S');
            [EVENT.PHASES(ind_S).WEIGHT] = deal(2);


            %%% 2) Extract Data (nood really need, only for plotting)
            [DATA,S]           = extract_DATA(EVENT,mainfile{1},debug);
            if isempty(DATA)
                disp('EVENT empty. Continue with next!');
                continue
            end

            % move per event extracted MSEED file into 'results_folder' under 'MSEED_files'
            mseed_store_path = [pwd, '/', results_folder, '/', 'MSEED_files'];
            if ~exist(mseed_store_path,'dir')
                mkdir(mseed_store_path);
            end
            mseed_store_name = [datestr(EVENT.ID,'YYYY-mm-dd_HH-MM-SS'), '.mseed'];
            movefile('./tmp/cat.mseed', [mseed_store_path, '/', mseed_store_name] )

            % if no original data name is given of the used waveforms, i.e. in the original s-file(s) line type '6', 
            % then in name of the MSSED file extracted (and processed) by this script is inserted.
            if isempty(EVENT.WAV)
                EVENT.WAV    = mseed_store_name;
            end

%TO BE EDITTED % debug
%TO BE EDITTED if debug
%TO BE EDITTED    plot_DATA(S);
%TO BE EDITTED    keyboard
%TO BE EDITTED end


            %%% 3) Clean event and relocate
            [EVENT_B,a,b] = rmsta_EVENT(EVENT,mainfile{1},mstan,limit_pha,limit_dev,debug);
            EVENT_C       = rmres_EVENT(EVENT_B,rms_thres,hyp,debug);

            if isempty(EVENT_C.LON)
                continue
            end

            S.EVENTS      = EVENT_C;

%TO BE EDITTED % debug
%TO BE EDITTED if debug; 
%TO BE EDITTED     plot_DATA(S)
%TO BE EDITTED     keyboard
%TO BE EDITTED end



            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% (2) Loop over mainfile(s) for refinement %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            %%% mention it
            fprintf(1,   'Step 2: loop over mainfile(s) for pick refinement\n');
            fprintf(fac, 'Step 2: loop over mainfile(s) for pick refinement\n');

            for k=1:numel(mainfile)


                %%% Refine picks 
                S = refine_PICKS(EVENT_C, mainfile{k}, 0);


%TO BE EDITTED  % debug
%TO BE EDITTED  if debug
%TO BE EDITTED      plot_DATA(S);
%TO BE EDITTED      keyboard
%TO BE EDITTED  end


                %%%  Clean event and relocate
                EVENT_D                          = S.EVENTS;
                [EVENT_E,station_reject,new_res] = rmsta_EVENT(EVENT_D,mainfile{k},mstan,limit_pha,limit_dev,debug);
                EVENT_F                          = rmres_EVENT(EVENT_E,rms_thres,hyp,debug);

                if isempty(EVENT_F.LON)
                    continue
                end

                S.EVENTS                         = EVENT_F;
                EVENT_C                          = EVENT_F;



%TO BE EDITTED  % debug / plot data
%TO BE EDITTED  if debug
%TO BE EDITTED      plot_DATA(S);
%TO BE EDITTED      keyboard
%TO BE EDITTED  end
%TO BE EDITTED  if plot_save == 1
%TO BE EDITTED      plot_DATA(S);
%TO BE EDITTED  end

            end



            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 3) AMPLITUDE CALCULATIONS %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            %%% mention it
            fprintf(1,   'Step 3: amplitude and magnitude calculations\n');
            fprintf(fac, 'Step 3: amplitude and magnitude calculations\n');


            S       = amp_EVENT(EVENT_C,mainfile{1},pz_file,flag_plot);
            EVENT_C = S.EVENTS;

            if debug
            	plot_DATA(S);
            	keyboard
            end



            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% 4) OUTPUT OF ALL RESULTS %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


            %%% mention it
            fprintf(1,   'Step 4: write output and store accordingly\n\n');
            fprintf(fac, 'Step 4: write output and store accordingly\n\n');


            %%% Define nordic output filename from ID (this is a name wanted by SEISAN to implement it easily into 'REA' ..)
            output_nordic  = [datestr(EVENT.ID,'dd-HHMM-SS'), 'L.S', datestr(EVENT.ID,'YYYYmm')];


            %%% Define path
            year_folder    = datestr(EVENT.ID,'YYYY');
            month_folder   = datestr(EVENT.ID,'mm');

            path_nordic    = [pwd, '/', results_folder, '/', year_folder, '/', month_folder, '/'];


            %%% Check if path exists
            if ~exist(path_nordic,'dir')
                mkdir(path_nordic)
            end


            %%% Write nordic
            event2nor(EVENT_C, output_nordic)


            %%% Movefile nordic
            movefile(output_nordic, path_nordic)



        catch ME
            warning(    'Problem for EVENT %s\n', EVENTS(j).ID);
            fprintf(fac,'Problem for EVENT %s\n', EVENTS(j).ID);
            fprintf(fac,'%s\n\n', ME.message);

            for k=1:length(ME.stack)
                fprintf(1,  '%s\n',    ME.message);
                fprintf(1,  '%s\n%i\n',ME.stack(k).name,ME.stack(k).line);
                fprintf(fac,'%s\n%i\n',ME.stack(k).name,ME.stack(k).line);
            end

        end
        fclose('all');

    end
    fclose('all');

end


%%% delete / move some tmp files that were created in pwd
system('rm -f data_used.file');
cmd = sprintf('mv -f gmap.cur.kml hyp.out hypmag.out hypsum.out print.out input.sfile %s', path_tmp);
system(cmd);


%%% move log file from tmp directory to results directory
movefile(log_file, results_folder);
[folder, baseFileName, ext] = fileparts(results_folder);
fprintf(1, 'Finished!\nResults (including log file) stored in:\n%s\n', [pwd, '/', baseFileName]);
