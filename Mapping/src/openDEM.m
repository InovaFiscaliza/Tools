classdef openDEM < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        method
        tile_index
        source_poi
        target_poi
        NWTile
        SWTile
        NETile
        SETile
        ZNW
        RNW
        ZSW
        RSW
        ZNE
        RNE
        ZSE
        RSE
        Z
        R
    end

    methods
        function obj = openDEM(datasource)
            %OPENDEM Construct an instance of this class
            %   receive a datasource and load the associated index file

            % check if datasouce is terminated in ".json"
            if ~endsWith(datasource,".json")
                method_status = "tile";
                
                % Load the index file into the tile index
                try
                    str=fileread(datasouce);
                    obj.tile_index=jsondecode(str);
                catch
                    error("Json tile index file not found");
                end
                
            else
                method_status = "service";
                error("open-elevation service alternative not implemented yet");
            end
        end

        function fnc_status = setPOI(obj,source_poi,target_poi)
            %setPOI Set the source and target points of interest
            % POI, Point of Interest, is a structure with the following fields:
            %   - lat: latitude
            %   - lon: longitude
            % Tiles will and LOS will be cached using the connecting points from source to target

            % Check if source and target POI are valid
            arguments
                obj
                source_poi struct
                target_poi struct
            end
            
            % Check if source and target POI are valid
            if ~isfield(source_poi,"lat") || ~isfield(source_poi,"lon") || ~(length(source_poi) >= 1)
                error("Invalid source POI");    
            end

            if ~isfield(target_poi,"lat") || ~isfield(target_poi,"lon") || ~(length(target_poi) >= 1)
                error("Invalid target POI");    
            end

            % Set the source and target POI
            obj.source_poi = source_poi;
            obj.target_poi = target_poi;

            % get maximum and minimum latitude and longitude
            lat = [source_poi.lat target_poi.lat];
            lon = [source_poi.lon target_poi.lon];

            latlim = [min(lat) max(lat)];
            lonlim = [min(lon) max(lon];

            if (latlim(2)-latlim(1)) > 2 || (lonlim(2)-lonlim(1)) > 2
                error("Area covered by the POI is too large");
            end

            % Get the NW, SW, NE, SE tiles considering that they are defined in the json file loaded int tile_index considering the following structure:
            %  [{"file": "data/N00W050_FABDEM_V1-2.tif", "coords": [0.0001388888888889106, 1.000138888888889, -50.00013888888889, -49.00013888888889]}]
            
            tile_name_segment = 'N00W05'
            
            tile_file_names=extractfield(obj.tile_index,'file');
            tile_matching = cellfun( @(x) contains(x,tile_name_segment), tile_file_names );
            tilename = find( match, 1 );

            try 
                [ZNW,RNW] = readgeoraster(NWTile,"OutputType","double");
                latlimNW = RNW.LatitudeLimits;
                lonlimNW = RNW.LongitudeLimits;
            catch
                error("NW Tile not found");
            end

            try 
                [ZSW,RSW] = readgeoraster(SWTile,"OutputType","double");
                latlimSW = RSW.LatitudeLimits;
                lonlimSW = RSW.LongitudeLimits;
            catch
                error("SW Tile not found");
            end

            try 
                [ZNE,RNE] = readgeoraster(NETile,"OutputType","double");
                latlimNE = RNE.LatitudeLimits;
                lonlimNE = RNE.LongitudeLimits;
            catch
                error("NE Tile not found");
            end

            try 
                [ZSE,RSE] = readgeoraster(SETile,"OutputType","double");
                latlimSE = RSE.LatitudeLimits;
                lonlimSE = RSE.LongitudeLimits;
            catch
                error("SE Tile not found");
            end


            [ZSW,RSW] = readgeoraster(RJtilepath2,"OutputType","double");
            latlimSW = RSW.LatitudeLimits;
            lonlimSW = RSW.LongitudeLimits;


            obj.Property1 = inputArg1 + inputArg2;
        end

        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

function [vis,visprofile,dist,h,lattrk,lontrk] = los_from_tiles(tile_set,lat1,lon1,lat2,lon2)
%LOS_FROM_TILES Expansion of LOS2 function to work with a tile repository
    
    % Test if tile set path is accessible
    [Z,R] = readgeoraster(tile_set,"OutputType","double");

    [vis,visprofile,dist,h,lattrk,lontrk] = los2(Z,R,lat1,lon1,lat2,lon2);

end