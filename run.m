%% VERSION CHECK

if (verLessThan('MATLAB','8.4'))
    error('The minimum required Matlab version is R2014b.');
end

%% CLEANUP

warning('off','all');
warning('on','MATLAB:HistoricalVolatility');

close('all');
clearvars();
clc();
delete(allchild(0));

%% INITIALIZATION

[path_base,~,~] = fileparts(mfilename('fullpath'));

if (~strcmpi(path_base(end),filesep()))
    path_base = [path_base filesep()];
end

if (~isempty(regexpi(path_base,'Editor')))
    path_base_fs = dir(path_base);
    is_live = ~all(cellfun(@isempty,regexpi({path_base_fs.name},'LiveEditorEvaluationHelper')));

    if (is_live)
        pwd_current = pwd();

        if (~strcmpi(pwd_current(end),filesep()))
            pwd_current = [pwd_current filesep()];
        end
        
        while (true) 
            answer = inputdlg('The script is being executed in live mode. Please, confirm or change its root folder:','Manual Input Required',1,{pwd_current});
    
            if (isempty(answer))
                return;
            end
            
            path_base_new = answer{:};

            if (isempty(path_base_new) || strcmp(path_base_new,path_base) || strcmp(path_base_new(1:end-1),path_base) || ~exist(path_base_new,'dir'))
               continue;
            end
            
            path_base = path_base_new;
            
            break;
        end
    end
end

if (~strcmpi(path_base(end),filesep()))
    path_base = [path_base filesep()];
end

paths_base = genpath(path_base);
paths_base = strsplit(paths_base,';');

for i = numel(paths_base):-1:1
    path_current = paths_base{i};

    if (~strcmp(path_current,path_base) && isempty(regexpi(path_current,[filesep() 'Scripts'])))
        paths_base(i) = [];
    end
end

paths_base = [strjoin(paths_base,';') ';'];
addpath(paths_base);

%% EXECUTION

file = fullfile(path_base,['Datasets' filesep() 'Example.xlsx']);
[tickers_1,data_1] = parse_dataset(file,'dd/mm/yyyy');

tickers_2 = {'GS'; 'JPM'};
date_begin = '2009-01-01';
date_end = '2019-12-31';
data_2 = fetch_data(tickers_2,date_begin,date_end);

tickers = [tickers_1; tickers_2];
data = [data_1; data_2];

for i = 1:numel(tickers)
    analyze_volatility(tickers{i},data{i},'YZ');
    compare_estimators(tickers{i},data{i},90);
end
