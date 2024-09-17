classdef openDEM < handle
    %OPENDEM provide DEM manipulation using multiple services
    %   This class provide methods for extracting information from Digital
    %   Elevation Models using a tile repository, web services (Open-Elevation) or 
    %   the original MathWorks service.

    properties (Constant)
        %-----------------------------------------------------------------%
        MATHWORKS_METHOD = 1; 
        TILE_METHOD      = 2;
        PUBLIC_METHOD    = 3;
    end


    properties
        %-----------------------------------------------------------------%
        method
        service_url char = 'https://fiscalizacao.anatel.gov.br/'
        tile_path char = 'not_defined'
        sep char = filesep
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
                obj.method = obj.MATHWORKS_METHOD;
                return;
            end

            srcData = varargin{1};
            [srcAddress, ~, srcExt] = fileparts(srcData);
            switch lower(srcExt)
                case '.json'
                    obj.method = obj.TILE_METHOD;
                    obj.tile_path = srcAddress;

                    % use objet specifc separator to allow for the use of
                    % web(http) or volume repository independent of platform
                    if contains(obj.tile_path,'/')
                        obj.sep = '/';
                    else
                        obj.sep = '\';
                    end
                
                    try
                        fileData = fileread(srcData);
                    catch
                        error('File not found');
                    end
                    try
                        [~, listOfFileName, listOfFileExt] = fileparts({jsondecode(fileData).file});
                    catch
                        error('%s file not in a recognized json format',srcData);
                    end

                    obj.tile_index = strcat(listOfFileName, listOfFileExt);

                otherwise
                    URL = regexp(srcData, '^http[s]?://[^\s]*', 'match', 'once');
                    if isempty(URL)
                        error('openDEM:UnexpectedSourceData', 'Unexpected source data')
                    end

                    obj.method = obj.PUBLIC_METHOD;
                    obj.service_url = URL;
            end

            if nargin == 2
                obj.max_tiles = varargin{2};
            end
        end
    end


    methods
        
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

            tile_name_segment = sprintf("%s%02d%s%03d",parallel_hemisphere,abs(lat),meridian_hemisphere,abs(lon));

            % search for the tile name in the tile index and return the full name
            tile_matching = cellfun( @(x) contains(x,tile_name_segment), obj.tile_index );
            
            index = find(tile_matching, 1 );
            if isempty(index)
                tile_filename = "";
            else
                tile_filename = strcat(obj.tile_path,obj.sep,obj.tile_index(index));
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
                    ilat = latmax - lat + 1;
                    ilon = lon - lonmin + 1;
                    tile_set{ilat,ilon} = get_tile_name(obj,lat,lon);
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

            % Copy the tile already loaded to the matrix considering it's position as defined by the ilat and ilon indexes
            latMinIndex = @(x) ((x-1)*tile_size(1))+1;
            latMaxIndex = @(x) ((x-1)*tile_size(1))+tile_size(1);
            lonMinIndex = @(x) ((x-1)*tile_size(2))+1;
            lonMaxIndex = @(x) ((x-1)*tile_size(2))+tile_size(2);

            obj.Z(latMinIndex(ilat):latMaxIndex(ilat),lonMinIndex(ilon):lonMaxIndex(ilon)) = Zf;

            % Create array to store latitude and longitude limits using the
            % limits of the first found tile.
            latLimits = repmat(Rf.LatitudeLimits,1,tiles_required);
            lonLimits = repmat(Rf.LongitudeLimits,1,tiles_required);

            % Initialize indexes of tile array to continue from the first
            % non empty tile
            limitArrayIndex = 3;
            jlat = ilat;
            jlon = ilon + 1;
            if jlon > meridian_size
                jlon = 1;
                jlat = ilat +1;
            end

            while jlat <= parallel_size
                while jlon <= meridian_size
                    if isempty(tile_set{jlat,jlon})
                        continue;
                    end

                    [Zf,Rs] = readgeoraster(tile_set{jlat,jlon},"OutputType","double");
                    obj.Z(latMinIndex(jlat):latMaxIndex(jlat),lonMinIndex(jlon):lonMaxIndex(jlon)) = Zf;
                    latLimits(limitArrayIndex:limitArrayIndex+1) = Rs.LatitudeLimits;
                    lonLimits(limitArrayIndex:limitArrayIndex+1) = Rs.LongitudeLimits;

                    jlon = jlon + 1;
                    limitArrayIndex = limitArrayIndex + 2;
                end
                jlon = 1;
                jlat = jlat + 1;
            end

            % Calculate the merged georeference for the complete tile matrix
            latlimN = max(latLimits);
            latlimS = min(latLimits);
            lonlimE = max(lonLimits);
            lonlimW = min(lonLimits);
            
            mergedlatlim = [latlimS latlimN];
            mergedlonlim = [lonlimW lonlimE];
            obj.R = georefpostings(mergedlatlim,mergedlonlim,size(obj.Z));
            
            % Copy remaining characteristics from the reference tile
            obj.R.ColumnsStartFrom = Rf.ColumnsStartFrom;
            obj.R.RowsStartFrom = Rf.RowsStartFrom;
            obj.R.SampleSpacingInLatitude = Rf.SampleSpacingInLatitude;
            obj.R.SampleSpacingInLongitude = Rf.SampleSpacingInLongitude;
            obj.R.GeographicCRS = Rf.GeographicCRS;
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
                target_POI_id int32
            end

            % get the source POI data using the id provided
            matchingIdx = arrayfun( @(x) x.id == source_POI_id,  obj.source_poi);

            if isempty(matchingIdx)
                error("Source POI with id %d not found",source_POI_id);
            end

            source = obj.source_poi(matchingIdx);

            % get the target POI data using the id provided in the array
            matchingIdx = arrayfun(@(x) ismember(x.id, target_POI_id), obj.target_poi);
            
            if length(find(matchingIdx)) ~= length(target_POI_id)
                warning("Some target POI ids not found");
            end

            target = obj.target_poi(matchingIdx);

            los_result = cell(length(target),1);

            for i = 1:length(target)
                   % calculate the line of sight profile
                [vis,visprofile,dist,h,lattrk,lontrk] = los2(obj.Z,obj.R,source.lat,source.lon,target(i).lat,target(i).lon);

                los_result{i} = struct('id',target(i).id,'visible',vis,'profile',visprofile,'distance',dist,'height',h,'lat',lattrk,'lon',lontrk);
            end
        end
    end
end
