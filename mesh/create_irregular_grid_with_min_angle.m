function [UV,F, res, edge_norms] = ...
  create_irregular_grid_with_min_angle( ...
    xRes, yRes, n, xWrap, yWrap, min_angle, ...
    no_interior, dart_threshold)
  % creates random UV positions and their connectivity information guaranteeing
  % min angle by wrapping trianlge (http://www.cs.cmu.edu/~quake/triangle.html)
  %
  % Usage:
  %   [V,F] = create_irregular_grid_with_min_angle(xRes, yRes, n, xWrap, yWrap)
  %
  % Input:
  %    n: number of points to create per block
  %    xWrap, yWrap: wrap around in X/Y direction
  %    min_angle: minimum angle between edges
  %    no_interior: don't generate an interior before sending to triangle
  %    dart_threshold: controls variation from regular
  %    

  % (C) 2008 Denis Kovacs/NYU
  % modified Alec Jacobson/NYU 2009

  %% stratified distribution

  % points along boundary like create_regular
  xRes = xRes -1;
  yRes = yRes -1;

  if(~exist('dart_threshold'))
    dart_threshold = 1.0; %(no threshold)
  end

  res = [yRes, xRes];


  xSpace = linspace(0,1,xRes+1); xSpace=xSpace(1:end-1);
  ySpace = linspace(0,1,yRes+1); ySpace=ySpace(1:end-1);
  % throw darts at random, using threshold to control how far from corner of
  % each cell. dart_threshold = 0.0 -> regular grid
  uvR = (1.0+dart_threshold*(rand((xRes-1)*(yRes-1)*n, 2))) ...
    .*repmat([xSpace(2), ySpace(2)], [(xRes-1)*(yRes-1)*n, 1]);
  [U,V] = meshgrid(xSpace(1:end-1), ySpace(1:end-1));
  uvB = repmat([U(:), V(:)], [n 1]);

% commented this out so dart_threshold==0 case would be exactly same vertex
% positions as regular
%  uvB(uvB(:,1)<0.001,1) = 0.001;
%  uvB(uvB(:,2)<0.001,2) = 0.001;
%  uvB(uvB(:,1)>0.999,1) = 0.999;
%  uvB(uvB(:,2)>0.999,2) = 0.999;

  uv = uvR + uvB;
  nUV = size(uv,1);
  nX = round(sqrt(n)*xRes); nY = round(sqrt(n)*xRes);

  % regularly place points on the boundaries
  xBorder = linspace(0.0,1.0,nX+1)';
  yBorder = linspace(0.0,1.0,nY+1);
  yBorder = yBorder(2:end-1)';

  % randomly place points on the boundaries
  %xBorder = [0; sort(rand(nX, 1)); 1];
  %yBorder = [sort(rand(nY, 1))];


  % vertices along the boundary of the domain, in order of their connectivity for
  % feeding into writePOLY()
  boundary = [[xBorder, 0*xBorder]; 
      [0*yBorder+1, yBorder];
      flipud([xBorder, 0*xBorder+1]); 
      flipud([0*yBorder, yBorder])];

  if(exist('no_interior') && no_interior)
    UV = [ boundary];
    % connectivity of boundary vertices
    boundary_segments = [(1:size(boundary,1)); ...
      [size(boundary,1) 1:(size(boundary,1)-1)]]';
  else
    UV = [uv; boundary];
    % connectivity of boundary vertices
    boundary_segments = [size(uv,1)+(1:size(boundary,1)); ...
      size(uv,1)+[size(boundary,1) 1:(size(boundary,1)-1)]]';
  end

  nUV = nUV + nX + nY;

  num_x = size(xBorder,1)-2;
  num_y = size(yBorder,1);
  num_interior = size(UV,1)-4-2*num_x-2*num_y;

  % print to .poly file
  %temp_file_name_prefix = '.temp';
  temp_file_name_prefix = tempname;
  writePOLY_triangle([temp_file_name_prefix '.poly'],UV(:,1:2), boundary_segments,[]);
  % execute triangle on .poly file
  preserve_boundary = '';
  if(yWrap || xWrap)
    preserve_boundary = 'Y';
  end

  %[UV,F] = execute_triangle( ...
  %  [['-p' preserve_boundary 'q'] num2str(min_angle)], temp_file_name_prefix);
  [UV,F] = triangle([temp_file_name_prefix '.poly'],'Quality',min_angle);
    %['-pq' num2str(min_angle)], temp_file_name_prefix);
  % remove poly file and obj file
  delete([temp_file_name_prefix '.poly']);

  % edges numbered same as opposite vertices
  edge_norms = [ ...
    sqrt(sum((UV(F(:,2),:)-UV(F(:,3),:)).^2,2)) ...
    sqrt(sum((UV(F(:,3),:)-UV(F(:,1),:)).^2,2)) ...
    sqrt(sum((UV(F(:,1),:)-UV(F(:,2),:)).^2,2)) ...
    ];

  % make a map to wrap vertex indices
  index_map = [1:size(UV,1)];

  % initial interior points are the same
  index_map(1:num_interior) = 1:num_interior;

  % bottom-left corner is the same
  index_map(num_interior+1) = num_interior+1;

  % bottom points are the same
  index_map(num_interior+1+1:num_interior+1+num_x) = ...
    num_interior+1+1:num_interior+1+num_x;

  % bottom right corner is the same only if not xWrap
  if(xWrap)
    % bottom left
    index_map(num_interior+1+num_x+1) = num_interior+1;
  else
    index_map(num_interior+1+num_x+1) = num_interior+1+num_x;
  end

  % right points are same only if not  xWrap
  if(xWrap)
    % left
    index_map( ...
      num_interior+1+num_x+1+1:num_interior+1+num_x+1+num_y) = ...
      fliplr(num_interior+1+num_x+1+num_y+1+num_x+1+1: ...
      num_interior+1+num_x+1+num_y+1+num_x+1+num_y);
  else
    index_map( ...
      num_interior+1+num_x+1:num_interior+1+num_x+1+num_y) = ...
      num_interior+1+num_x+1:num_interior+1+num_x+1+num_y;
  end

  % top right is same only if not x wrap and not y wrap
  if(yWrap && xWrap)
    % bottom left
    index_map(num_interior+1+num_x+1+num_y+1) = ...
      num_interior+1;
  elseif(xWrap)
    % top left
    index_map(num_interior+1+num_x+1+num_y+1) = ...
      num_interior+1+num_x+1+num_y+1+num_x+1;
  elseif(yWrap)
    % bottom right
    index_map(num_interior+1+num_x+1+num_y+1) = ...
      num_interior+1+num_x+1;
  else
    index_map(num_interior+1+num_x+1+num_y+1) = ...
      num_interior+1+num_x+1+num_y+1;
  end

  % top is the same only if not x wrap
  if(yWrap)
    % bottom
    index_map(num_interior+1+num_x+1+num_y+1+1: ...
      num_interior+1+num_x+1+num_y+1+num_x) = ...
      fliplr(num_interior+1+1:num_interior+1+num_x);
  else
    index_map(num_interior+1+num_x+1+num_y+1+1: ...
      num_interior+1+num_x+1+num_y+1+num_x) = ...
      num_interior+1+num_x+1+num_y+1+1: ...
      num_interior+1+num_x+1+num_y+1+num_x;
  end

  % top left corner is only same if not yWrap 
  if(yWrap)
    % bottom left
    index_map(num_interior+1+num_x+1+num_y+1+num_x+1) = ...
      num_interior+1;
  else
    index_map(num_interior+1+num_x+1+num_y+1+num_x+1) = ...
      num_interior+1+num_x+1+num_y+1+num_x+1;
  end

  % left is always the same
  index_map(num_interior+1+num_x+1+num_y+1+num_x+1+1: ...
    num_interior+1+num_x+1+num_y+1+num_x+1+num_y) = ...
    num_interior+1+num_x+1+num_y+1+num_x+1+1: ...
    num_interior+1+num_x+1+num_y+1+num_x+1+num_y;

  % steiner point are the same
  index_map(num_interior+1+num_x+1+num_y+1+num_x+1+num_y+1:size(UV,1)) = ...
    num_interior+1+num_x+1+num_y+1+num_x+1+num_y+1:size(UV,1);
 
  F = [index_map(F(:,1))' index_map(F(:,2))' index_map(F(:,3))'];
  

end
