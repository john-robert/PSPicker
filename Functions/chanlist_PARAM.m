%%% List all channels that need to be processed


function channelIDS=chanlist_PARAM(PickerParam)

    channelIDS={};

    for station=fieldnames(PickerParam.Station_param)';
    	%disp(station);
        for type=fieldnames(PickerParam.Station_param.(station{1}))';
        %	disp('joar');
        %	disp(type);
            if ~isempty(PickerParam.Station_param.(station{1}).(type{1}))
                for phase=fieldnames(PickerParam.Station_param.(station{1}).(type{1}))';
                    channelID=PickerParam.Station_param.(station{1}).(type{1}).(phase{1}).channelID;
                    channelIDS=[channelIDS channelID];
                end
            end
            
        end

    %disp(station);
    %disp('channels:');
    %disp(unique(channelIDS));
    end
    channelIDS=unique(channelIDS);

end
