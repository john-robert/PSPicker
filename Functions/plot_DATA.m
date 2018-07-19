%%%%% Program made to plot data from a DATA structure
%%% Type 1 if you want all components


function f=plot_DATA(varargin)


    %%% Check is not empty
    %switch nargin
    %    case 0
    %        fprintf(1,'No inputs given\n');
    %        return;
    %    case 1
    %        plot_save = varargin{2};
    %        inputargs = varargin{1};
    %    end
    plot_save = 1;

    %%% Parsing arguments
    p = inputParser;
    defaultParam =false;
    addRequired(p,'DATA',@(x) isstruct(x));
    addParamValue(p,'filter',defaultParam, @(x) isnumeric(x));
    addParamValue(p,'stations',defaultParam, @(x) iscell(x));
    addParamValue(p,'channels',defaultParam, @(x) iscell(x));
    addParamValue(p,'type','VEL', @(x) ischar(x));              %%% If not specified the plot will display the raw value
    addParamValue(p,'components',defaultParam, @(x) iscell(x));
    addParamValue(p,'start',defaultParam, @(x) isnumeric(x));
    addParamValue(p,'end',defaultParam, @(x) isnumeric(x));

    parse(p,varargin{:});
    S = p.Results.DATA;
    DATA=S.DATA;
    EVENTS=S.EVENTS;
    
    stations = p.Results.stations;
    channels = p.Results.channels;
    components = p.Results.components;
    start_time=p.Results.start;
    end_time=p.Results.end;
    type=p.Results.type;
    filter_value=p.Results.filter;
    
    if ~iscell(stations) & stations==0
        stations={DATA(:).STAT};
    end
    if ~iscell(channels) & channels==0
        channels='1';
    end
    if ~iscell(components) & components==0
        components='1';
    end

    %%% Start Plotting

    %%% Get an origin time for traces

    origin_datenum= DATA(1).RAW(1).TIMESTART;


    %%% Plot figure
    shift=0;
    channel_cell={};

    if plot_save == 0
        f=figure('KeyPressFcn',@(obj,evt) 0);
        set(f,'visible','off');
        hold on;
    elseif plot_save == 1
        f=figure('visible','off');
    end

    new_min=0;
    new_max=0;
    flag_exist=0;
    
    %%% Reorder stations depending on distance for plotting if location has
    %%% computed prior to plotting, only if one event exist
    
    if numel(EVENTS)==1 && ~isempty(EVENTS.LON) && isempty(isempty_PHASE(EVENTS.PHASES))
        [~,ind_dis]=get_PHASE(EVENTS.PHASES,'station',stations,'type','P');
        select_distance=[EVENTS.PHASES(ind_dis).DIS]';
        select_station={EVENTS.PHASES(ind_dis).STATION}';
        [~,ind_order]=sort(select_distance,'descend');
        select_station1=select_station(ind_order);
        select_station2={DATA(:).STAT}';
        
        [Lia,Locb] = ismember(select_station1,select_station2);
        
        SCRATCH=DATA(Locb);
        clear DATA;
        DATA=SCRATCH;
    end
    
    %%% Start plotting
    
    for i=1:length(DATA)

        if ~strcmp(stations,DATA(i).STAT)
            continue
        end
        
        %%% Get station name
        
        station=DATA(i).STAT;
        
        flag_exist=1;
        
        OUT_DATA = select_DATA(DATA,DATA(i).STAT,'comp',components,'chan',channels);

        for j=1:length(OUT_DATA.RAW)
            
            %%% Define what type of trace we have to plot 'VEL' or 'DISP'
            %%% If 'DISP' is empty then go to next channel
            
            switch type
                case 'VEL'
                    trace=OUT_DATA.RAW(j).TRACE;
                case 'DISP'
                    if isempty(OUT_DATA.RAW(j).DISP)
                        continue
                    else
                        trace=OUT_DATA.RAW(j).DISP;
                    end
            end

            %%% Get the x axis

            xax=(0:length(trace)-1)/(OUT_DATA.RSAMPLE) + (OUT_DATA.RAW(j).TIMESTART-origin_datenum)*86400;

            OUT_DATA.STAT;
            OUT_DATA.RAW(j).CHAN;
            (OUT_DATA.RAW(j).TIMESTART-origin_datenum)/86400;

            %%% Process the trace
            if filter_value~=false
                trace=filterbutter(3,filter_value(1),filter_value(2),OUT_DATA.RSAMPLE,trace);
            end
            trace=trace-mean(trace(~isnan(trace)));    % Correct from the mean
            
            %%% Find the maximum in the between start time and end_time
            
            if start_time
                max_trace=max(abs(trace(xax>=start_time & xax<=end_time)));
            else
                max_trace=max(abs(trace));
            end
            trace=trace./max_trace/(2);   % Normalize the trace
            trace=trace+shift;

            %%% Plot the station trace

            h(j)=plot(xax,trace,'k');
            
            %%% Plot the maximum value
            
            text2plot=sprintf('abs. max. = %.3g',max_trace);
            text(0,shift+0.5,text2plot,'color',[1 0 0]);

            %%% Plot the Picks

            for k=length(EVENTS):-1:1
                
%                 if ~isempty(EVENTS(k).ORIGIN)
%                 %%% Check if event origin time in interval
%                 origin_event=(EVENTS(k).ORIGIN - origin_datenum)*86400;                
%                     if (origin_event < xax(1) | origin_event > xax(end))
%                         continue
%                     end
%                 end
                
                color=EVENTS(k).COLOR;
                if isempty(color)
                    color=[1 0 0];
                end
                
                PHASES=EVENTS(k).PHASES;
                
                %%% Get proper station
                
                STA_PHASES=get_PHASE(PHASES,'station',station);
                
                for m=1:length(STA_PHASES)
                   
                    %%% Plot arrivals
                    
                    ARRIVAL=STA_PHASES(m).ARRIVAL;
                    WEIGHT=sprintf('%i  ',STA_PHASES(m).WEIGHT);
                    ARRIVAL=(ARRIVAL - origin_datenum)*86400;
                    ARRIVAL=ARRIVAL(ARRIVAL> xax(1) & ARRIVAL < xax(end));
                    if ~isempty(ARRIVAL)
                        plot([ARRIVAL ARRIVAL],[-0.5 0.5]+shift ,'color',color,'linewidth',2);
                        text(ARRIVAL,0.6+shift,['\color{red}',WEIGHT],...
                            'Horizontalalignment','center');
                    end
                    
                    %%% Plot theoretical
                    
                    THEO=STA_PHASES(m).THEO;
                    THEO=(THEO - origin_datenum)*86400;
                    THEO=THEO(THEO> xax(1) & THEO < xax(end));
                    if ~isempty(THEO)
                        plot([THEO THEO],[-0.5 0.5]+shift ,'--r','color',[0 0.5 0.2],'linewidth',2);
                    end
                end
                
                %%% Plot origin time with text

                ORIGIN=(EVENTS(k).ORIGIN - origin_datenum)*86400;
                if ~isempty(ORIGIN)
                    plot([ORIGIN ORIGIN],[-0.5 0.5]+shift ,'--r','linewidth',1);
                    if (j==length(OUT_DATA.RAW) & i==length(DATA))
                        text(ORIGIN,0.8+shift,['     ','\color{red}',datestr(EVENTS(k).ORIGIN)],'Horizontalalignment','center','fontsize',10);
                    end
                end
%                 index_c=strcmp(EVENTS(k).PHASES.STATION,station);
%                 
%                 arrivals=EVENTS(k).PHASES.ARRIVAL;
%                 arrivals=arrivals(index_c);
%                 arrivals = (arrivals - origin_datenum)*86400;
%                 arrivals=arrivals(arrivals> xax(1) & arrivals < xax(end));
%                 
                
%                 types=EVENTS(k).PHASES.TYPE;
%                 for m=1:length(arrivals)
%                    plot([arrivals(m) arrivals(m)],[-0.5 0.5]+shift ,'color',color,'linewidth',2);
%                    %text(arrivals(m),0.5+shift,types{m})
%                 end
%                  if ~isempty(EVENTS(k).PHASES.THEO);
%                 theo=EVENTS(k).PHASES.THEO;
%                 theo=theo(index_c);
%                 theo = (theo - origin_datenum)*86400;
%                 theo=theo(theo> xax(1) & theo < xax(end));
%                 
%                 for m=1:length(theo)
%                    plot([theo(m) theo(m)],[-0.5 0.5]+shift ,'-.k','color',[0 0.5 0.2],'linewidth',1);
%                    %text(arrivals(m),0.5+shift,types{m})
%                 end
%                  end
%                 if ~isempty(EVENTS(k).ORIGIN)
%                     origin_event=(EVENTS(k).ORIGIN - origin_datenum)*86400;
%                     plot([origin_event origin_event],[-0.5 0.5]+shift ,'--r','linewidth',1);
% 
%                     if (j==length(OUT_DATA.RAW) & i==length(DATA))
%                         text(origin_event,0.8+shift,['     ','\color{red}',datestr(EVENTS(k).ORIGIN)],'Horizontalalignment','center','fontsize',10);
%                     end
%                 end
                
            end
            %%% Station name

            channel_name=[OUT_DATA.STAT,' ',OUT_DATA.RAW(j).CHAN,' ',OUT_DATA.RAW(j).COMP];
            channel_cell=[channel_cell channel_name];

            %%% Apply shift

            shift=shift+1;

            new_min=min(new_min,xax(1));
            new_max=max(new_max,xax(end));

            xlim([new_min new_max]);
        end

    end


    if flag_exist==0
        fprintf(1,'No stations can be displayed\n');
        close(f);
        return
    end
    

    set(f,'visible','on');

    %%% Set figure proprties

    screen=get(0,'screensize');
    height=screen(4);
    set(f, 'Position', [screen(3)/3 screen(4)/4 height*0.8 height*0.6]);
    ax=gca;

    if start_time
        new_min=start_time;
        new_max=end_time;
    end
    xlim([new_min new_max]);

    xlab=cellstr(get(ax,'Xticklabel'));
    titlename=datestr(origin_datenum,'dd-mmm-yyyy HH:MM:SS.FFF');
    xlab{1}=titlename;

    title(titlename,'fontsize',15);
    box on;

    set(ax,'Ylim',[-1 length(channel_cell)]);
    set(ax,'Ytick',(0:length(channel_cell)-1));
    set(ax,'Yticklabel',channel_cell);
    %set(ax,'Xticklabel',xlab,'fontsize',12);


    hold off;
    xlabel('Time (sec)','fontsize',15);

    
    if plot_save == 1
        plot_name = strrep(titlename,' ','_');
        plot_name = strrep(plot_name,':','-');
        imwrite(f, [plot_name,'.png'])
    end
    % limit=xlim;
    % w = waitforbuttonpress;

end
