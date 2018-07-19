% function made to compute the synthetic given an event stored in the structure 
% given by read_EVENTS()


function new_event=comp_THEO(params,hyp,event,debug)


    %%% Go into hyp/ dir to avoid stuffing current dir
    cd('tmp');


    %%% Define input_output files
    sfile_input    = 'input.sfile';
    sfile_output   = 'output.sfile';


    %%% Create sfile
    event2nor(event,sfile_input);


    %%% Compute synthetics
    comp_ARRIVALS(params,hyp,sfile_input,sfile_output,debug)


    %%% Read sfile
    new_event        = nor2event(sfile_output);


    %%% Read first loc
    first_event      = nor2event('first_loc.out');
    new_new          = first_event;
    new_new.PHASES   = new_event.PHASES;


    %%% Merge events
    new_event        = merge_events(first_event,new_new);
    new_event.COLOR  = event.COLOR;
    new_event.AGENCY = event.AGENCY;
    new_event.ID     = event.ID;
    new_event.WAV    = event.WAV;


    %%% Move files to temp directory files
    system('rm -f hypmag.out hypsum.out print.out');


    %%% Go back to top directory
    cd('../');
end


%%% Add theo to the initial event
function a=merge_events(event,new_event)

    nums                          = numel(new_event.PHASES);
    [new_event.PHASES(:).THEO]    = new_event.PHASES(:).ARRIVAL;


    %%% Reset arrival to empty
    [new_event.PHASES(:).ARRIVAL] = deal([]);


    %%% Define set of types and station for strcmp
    type_event     = {event.PHASES(:).TYPE};
    station_event  = {event.PHASES(:).STATION};

    for i=1:nums
        station    = new_event.PHASES(i).STATION;
        type       = new_event.PHASES(i).TYPE;
        ind        = find((strcmp(station,station_event) & strcmp(type,type_event))==1);
        if length(ind)==1;
            new_event.PHASES(i).INSTRUMENT = event.PHASES(ind).INSTRUMENT;
            new_event.PHASES(i).COMPONENT  = event.PHASES(ind).COMPONENT;
            new_event.PHASES(i).ARRIVAL    = event.PHASES(ind).ARRIVAL;
            new_event.PHASES(i).WEIGHT     = event.PHASES(ind).WEIGHT;
        else
            continue
        end
    end


    %%% Compute RMS
    for j=1:numel(new_event.PHASES)
       new_event.PHASES(j).RMS = (new_event.PHASES(j).ARRIVAL-new_event.PHASES(j).THEO).*86400;
    end

    a = new_event;
end

