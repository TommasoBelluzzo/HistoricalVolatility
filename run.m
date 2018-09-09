warning('off','all');

close('all');
clearvars();
clc();

[path,~,~] = fileparts(mfilename('fullpath'));

if (~strcmpi(path(end),filesep()))
    path_base = [path filesep()];
end

paths_base = genpath(path);
addpath(paths_base);

analyse_volatility('JPM',2010,2017,'YZ');
compare_estimators('JPM',2010,2017,90);

rmpath(paths_base);
