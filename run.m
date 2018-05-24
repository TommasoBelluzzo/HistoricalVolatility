warning('off','all');

close('all');
clearvars();
clc();

[path,~,~] = fileparts(mfilename('fullpath'));
paths = genpath(path);
addpath(paths);

analyse_volatility('YAHOO/JPM',2010,2017,'YZ');
compare_estimators('YAHOO/JPM',2010,2017,90);

rmpath(paths);
