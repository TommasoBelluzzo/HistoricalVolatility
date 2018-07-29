warning('off','all');

close('all');
clearvars();
clc();

[path_base,~,~] = fileparts(mfilename('fullpath'));

if (~endsWith(path_base,filesep()))
    path_base = [path_base filesep()];
end

files = dir([path_base '\**\*.m']);
deps = {};

for i = 1:numel(files)
   file = files(i);
   file_path = fullfile(file.folder,file.name);

   [~,file_deps] = matlab.codetools.requiredFilesAndProducts(file_path);
   deps = [deps; {file_deps.Name}.'];
   
end

deps = sort(unique(deps));


paths_base = genpath(path_base);
addpath(paths_base);

analyse_volatility('JPM',2010,2017,'YZ');
compare_estimators('JPM',2010,2017,90);

rmpath(paths_base);