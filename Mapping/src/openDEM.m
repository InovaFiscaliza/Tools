classdef openDEM < handle
    %OPENDEM provide DEM manipulation using multiple services
    %   This class provide methods for extracting information from Digital
    %   Elevation Models using a tile repository, web services (Open-Elevation) or 
    %   the original MathWorks service.

    properties (Constant, Access = private)
        %-----------------------------------------------------------------%
        MATHWORKS_SERVICE = 1; 
        TILE_SERVICE      = 2;
        PUBLIC_SERVICE    = 3;
    end


    properties
        %-----------------------------------------------------------------%
        method
        service_url char = 'https://fiscalizacao.anatel.gov.br/'
        tile_path
        tile_index
        max_tiles   int16 {mustBePositive, mustBeLessThanOrEqual(max_tiles, 32)} = 4
        source_poi
        target_poi
        Z
        R
    end


    methods
        %-----------------------------------------------------------------%
        function obj = openDEM(varargin)
            %OPENDEM Construct an instance of this class
            %   Default method is the MathWorks service; if no parameters are passed
            %   If a JSON file is passed, the tile service is used
            %   If a URL is passed, the public service is used
            %   Optional parameters: max_tiles, maximum number of tiles to be cached, default is 4

            if ~nargin
                obj.method = obj.MATHWORKS_SERVICE;
                return;
            end

            srcData = varargin{1};
            [srcAddress, ~, srcExt] = fileparts(srcData);
            switch lower(srcExt)
                case '.json'
                    obj.method = obj.TILE_SERVICE;
                    obj.tile_path = srcAddress;

                    jsonContent = jsondecode(fileread(srcData));
                    [~, listOfFileName, listOfFileExt] = fileparts({jsonContent.file});
                    obj.tile_index = strcat(listOfFileName, listOfFileExt);

                otherwise
                    URL = regexp(srcData, '^http[s]?://[^\s]*', 'match', 'once');
                    if isempty(URL)
                        error('openDEM:UnexpectedSourceData', 'Unexpected source data')
                    end

                    obj.method = obj.PUBLIC_SERVICE;
                    obj.service_url = URL;
            end

            if nargin == 2
                obj.max_tiles = varargin{2};
            end
        end
    end


    methods
        %-----------------------------------------------------------------%
        function cleanName = cleanFileName(dirtyName)
            %CLEAN_FILE_NAMES Remove unwanted path from tile file names
            %   Tiles are supposed to be stored in the same directory of the json index.
            %   The path to the directory is not needed in the obj.tile_index variable
            
            lastdot_pos = find(dirtyName == '\', 1, 'last');
            if isempty(lastdot_pos)
                lastdot_pos = find(dirtyName == '/', 1, 'last');
                if isempty(lastdot_pos)
                    cleanName = dirtyName;
                    return;
                end
            end
            cleanName = extractAfter(dirtyName,lastdot_pos);
        end
        
        %-----------------------------------------------------------------%
        function tile_filename = get_tile_name(obj,lat,lon)
            %GET_TILE_NAME Get the name of the tile that that contains lat and lon
            %  latitude and longitude must be integers and represente the left bottom corner 
            %         of the tile (minimum latitude and longitude)
            %  Tile name includes a string in the format "PhDDMhEEE", where:
            %         Ph is the hemisphere,
            %         DD is the integer part of the latitude,
            %         Mh is the hemisphere of the meridian,
            %         EE is the integer part of the longitude.
            
            if lat < 0
                parallel_hemisphere = "S";
            else
                parallel_hemisphere = "N";
            end

            if lon < 0
                meridian_hemisphere = "W";
            else
                meridian_hemisphere = "E";
            end

            tile_name_segment = sprintf("%s%02d%s%03d",parallel_hemisphere,lat,meridian_hemisphere,lon);

            % search for the tile name in the tile index and return the full name
            tile_matching = cellfun( @(x) contains(x,tile_name_segment), obj.tile_index );
            
            index = find(tile_matching, 1 );
            if isempty(index)
                tile_filename = "";
            else
                tile_filename = strcat(obj.tile_path,'/',obj.tile_index(index));
            end
        end

        %-----------------------------------------------------------------%
        function obj = get_tiles(obj)
            %GET_TILES private method to get the tiles from POI
            %   The method will get the tiles that cover the area between the source and target POI, and store them in the object properties

            % get reference coordinates and sizes from the POI
            POI_lat = [obj.source_poi.lat obj.target_poi.lat];
            POI_lon = [obj.source_poi.lon obj.target_poi.lon];

            latmin = floor(min(POI_lat));
            latmax = floor(max(POI_lat));
            lonmin = floor(min(POI_lon));
            lonmax = floor(max(POI_lon));
            
            parallel_size = latmax - latmin + 1;
            meridian_size = lonmax - lonmin + 1;
            tiles_required = parallel_size * meridian_size;

            % validate if the number of tiles required is within the limit
            if tiles_required > obj.max_tiles
                error("%d tiles required to cover the POI. Maximum number of tiles is %d",tiles_required,obj.max_tiles);
            end

            % create a cell array to store the tile names from the object tile index
            tile_set = cell(parallel_size,meridian_size);

            for lat = latmin:1:latmax
                for lon = lonmin:1:lonmax
                    ilat = lat - latmin + 1;
                    ilon = lon - lonmin + 1;
                    tile_set{ilat,ilon} = get_tile_name(lat,lon);
                end
            end

            % loop through the tile set until the first tile is found and load it. Tiles might be missing, specially in costal regions.
            for ilat = 1:parallel_size
                for ilon = 1:meridian_size
                    if ~isempty(tile_set{ilat,ilon})
                        found = true;
                        break;
                    end
                end
                if found
                    break;
                end
            end
            [Zf,Rf] = readgeoraster(tile_set{ilat,ilon},"OutputType","double");

            % Alocate memory for the complete tile matrix
            tile_size = size(Zf);
            obj.Z = zeros(tile_size(1) * parallel_size, tile_size(2) * meridian_size, 'double');
            Rarray = cell(parallel_size,meridian_size);

            % Copy the tile already loaded to the matrix considering it's position as defined by the ilat and ilon indexes
            obj.Z{((ilat-1)*tile_size(1))+1:((ilat-1)*tile_size(1))+tile_size(1),((ilon-1)*tile_size(2))+1:((ilon-1)*tile_size(2))+tile_size(2)} = Zf;
            Rarray{ilat,ilon} = Rf;

            % Continue the loop through tile set and load the remaining tiles into the object
            for jlat = ilac:parallel_size
                for jlon = ilon:meridian_size
                    if isempty(tile_set{jlat,jlon})
                        continue;
                    end
                    [Zf,Rf] = readgeoraster(tile_set{jlat,jlon},"OutputType","double");
                    obj.Z(((jlat-1)*tile_size(1))+1:((jlat-1)*tile_size(1))+tile_size(1),((jlon-1)*tile_size(2))+1:((jlon-1)*tile_size(2))+tile_size(2)) = Zf;
                    Rarray{jlat,jlon} = Rf;
                end
            end

            % Calculate the merged georeference for the complete tile matrix
            latlimN = Rarray{1,1}.LatitudeLimits(2);
            lonlimW = Rarray{1,1}.LongitudeLimits(1);
            latlimS = Rarray{parallel_size,1}.LatitudeLimits(1);
            lonlimE = Rarray{1,meridian_size}.LongitudeLimits(2);
            mergedlatlim = [latlimS latlimN];
            mergedlonlim = [lonlimW lonlimE];
            obj.R = georefpostings(mergedlatlim,mergedlonlim,size(obj.Z));
            obj.R.GeographicCRS = Rarray{1,1}.GeographicCRS;
        end

        %-----------------------------------------------------------------%
        function fnc_ok = setPOI(obj,source_poi,target_poi)
            %setPOI Set the source and target points of interest
            % POI, Point of Interest, is a structure with the following fields:
            %   - id: unique identifier of the POI
            %   - lat: latitude, in decimal degrees
            %   - lon: longitude, in decimal degrees
            % Tiles will and LOS will be cached using the connecting points from source to target

            arguments
                obj
                source_poi struct
                target_poi struct
            end
            
            fnc_ok = true;

            if (~isfield(source_poi,"lat") || ~isfield(source_poi,"lon") || ~(length(source_poi) >= 1))
                warning("Invalid source POI");
                fnc_ok = false;
            end

            if (~isfield(target_poi,"lat") || ~isfield(target_poi,"lon") || ~(length(target_poi) >= 1))
                warning("Invalid target POI");    
                fnc_ok = false;
            end

            obj.source_poi = source_poi;
            obj.target_poi = target_poi;

            get_tiles(obj);
        end

        %-----------------------------------------------------------------%
        function los_result = los(obj,source_POI_id,target_POI_id)
            %LOS Line of Sight calculation
            %   Calculate the Line of Sight between the source and target POI
            arguments
                obj
                % single id for source
                source_POI_id int32
                % array of ids for target
                target_POI_id array
            end

            % get the source POI data using the id provided
            source = obj.source_poi(obj.source_poi.id == source_POI_id);
            if isempty(source)
                error("Source POI with id %d not found",source_POI_id);
            end

            % get the target POI data using the id provided in the array
            target = obj.target_poi(obj.target_poi.id == target_POI_id);
            if length(target) ~= length(target_POI_id)
                warning("Some target POI ids not found");
            end

            los_result = cell(length(target),1);

            for i = 1:length(target)
                   % calculate the line of sight profile
                [vis,visprofile,dist,h,lattrk,lontrk] = los2(obj.Z,obj.R,source.lat,source.lon,target(i).lat,target(i).lon);

                los_result{i} = struct('id',target(i).id,'visible',vis,'profile',visprofile,'distance',dist,'height',h,'lat',lattrk,'lon',lontrk);
            end
        end
    end
end
