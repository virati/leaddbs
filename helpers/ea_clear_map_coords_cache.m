function ea_clear_map_coords_cache()
% Clear persistent caches used by ea_map_coords and ea_get_affine
%
% This function clears the internal caches used to speed up coordinate
% mapping operations. Call this if you:
% - Are running low on memory
% - Have updated transformation files
% - Want to ensure fresh reads from disk
%
% Usage:
%   ea_clear_map_coords_cache();

fprintf('Clearing ea_map_coords caches...\n');

% Clear ea_get_affine cache
clear ea_get_affine;

% Clear ea_map_coords internal function caches
clear functions;

fprintf('Caches cleared.\n');
