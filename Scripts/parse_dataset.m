% [INPUT]
% file = A string representing the full path to the Excel spreadsheet containing the dataset.
% date_format = A string representing the date format used in the Excel spreadsheet (optional, default='dd/mm/yyyy').
%
% [OUTPUT]
% tickers = A cell array of strings representing the parsed ticker symbols.
% data = A cell array of tables representing the parsed time series. Each table has the following columns:
%   - Date (numeric observation dates)
%   - Open (opening prices)
%   - High (highest prices)
%   - Low (lowest prices)
%   - Close (closing prices)
%   - Return (log returns)

function [tickers,data] = parse_dataset(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('file',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1 NaN]}));
        ip.addOptional('date_format','dd/mm/yyyy',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1 NaN]}));
    end

    ip.parse(varargin{:});

    ipr = ip.Results;
    [file,tickers] = validate_file(ipr.file);
    date_format = validate_date_format(ipr.date_format);
    
    nargoutchk(2,2);

    data = parse_dataset_internal(file,tickers,date_format);

end

function data = parse_dataset_internal(file,tickers,date_format)

    k = numel(tickers);
    data = cell(k,1);

    for i = 1:k
        if (verLessThan('MATLAB','9.1'))
            if (ispc())
                try
                    tab = readtable(file,'Sheet',i,'Basic',true);
                catch
                    tab = readtable(file,'Sheet',i);
                end
            else
                tab = readtable(file,'Sheet',i);
            end

            if (~all(cellfun(@isempty,regexp(tab.Properties.VariableNames,'^Var\d+$','once'))))
                error(['The ''' name ''' sheet contains unnamed columns.']);
            end

            if (~all(strcmp({'Date' 'Open' 'High' 'Low' 'Close'},options.VariableNames)))
                error(['The ''' name ''' sheet must define the following columns, in the exact same order: ''Date'', ''Open'', ''High'', ''Low'' and ''Close''.']);
            end

            tab.Date = datetime(tab.Date,'InputFormat',strrep(date_format,'m','M'));

            output_vars = varfun(@class,tab,'OutputFormat','cell');

            if (~all(strcmp(output_vars(2:end),'double')))
                error(['The ''' name ''' sheet contains invalid or missing values.']);
            end
        else
            if (ispc())
                options = detectImportOptions(file,'Sheet',i);
            else
                options = detectImportOptions(file,'Sheet',name);
            end

            if (~all(cellfun(@isempty,regexp(options.VariableNames,'^Var\d+$','once'))))
                error(['The ''' name ''' sheet contains unnamed columns.']);
            end

            if (~all(strcmp({'Date' 'Open' 'High' 'Low' 'Close'},options.VariableNames)))
                error(['The ''' name ''' sheet must define the following columns, in the exact same order: ''Date'', ''Open'', ''High'', ''Low'' and ''Close''.']);
            end

            options = setvartype(options,[{'datetime'} repmat({'double'},1,numel(options.VariableNames) - 1)]);
            options = setvaropts(options,'Date','InputFormat',strrep(date_format,'m','M'));

            if (ispc())
                try
                    tab = readtable(file,options,'Basic',true);
                catch
                    tab = readtable(file,options);
                end
            else
                tab = readtable(file,options);
            end
        end

        if (any(any(ismissing(tab))) || any(any(~isfinite(tab{:,2:end}))))
            error(['The ''' name ''' sheet contains invalid or missing values.']);
        end

        if (any(any(tab{:,2:end} < 0)))
            error(['The ''' name ''' sheet contains negative values.']);
        end

        t = height(tab);
        dates_num = datenum(tab.Date);

        if (t ~= numel(unique(dates_num)))
            error(['The ''' name ''' sheet contains duplicate observation dates.']);
        end

        if (any(dates_num ~= sort(dates_num)))
            error(['The ''' name ''' sheet contains unsorted observation dates.']);
        end

        tab.Date = dates_num;
        tab.Return = [NaN; diff(log(tab.Close))];

        data{i} = tab;
    end

end

%% VALIDATION

function date_format = validate_date_format(date_format)

    try
        datestr(now(),date_format);
    catch e
        error(['The date format ''' date_format ''' is invalid.' newline() strtrim(regexprep(e.message,'Format.+$',''))]);
    end
    
    if (any(regexp(date_format,'(?:HH|MM|SS|FFF|AM|PM)')))
        error('The date format must not include time information.');
    end
    
end

function [file,tickers] = validate_file(file)

    if (exist(file,'file') == 0)
        error(['The dataset file ''' file ''' could not be found.']);
    end

    [~,~,extension] = fileparts(file);

    if (~strcmp(extension,'.xlsx'))
        error(['The dataset file ''' file ''' is not a valid Excel spreadsheet.']);
    end

    if (verLessThan('MATLAB','9.7'))
        if (ispc())
            [file_status,file_sheets,file_format] = xlsfinfo(file);

            if (isempty(file_status) || ~strcmp(file_format,'xlOpenXMLWorkbook'))
                error(['The dataset file ''' file ''' is not a valid Excel spreadsheet.']);
            end
        else
            [file_status,file_sheets] = xlsfinfo(file);

            if (isempty(file_status))
                error(['The dataset file ''' file ''' is not a valid Excel spreadsheet.']);
            end
        end
    else
        try
            file_sheets = sheetnames(file);
        catch
            error(['The dataset file ''' file ''' is not a valid Excel spreadsheet.']);
        end
    end
    
    tickers = file_sheets(:);

end
