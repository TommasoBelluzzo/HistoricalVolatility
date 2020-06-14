% [INPUT]
% tickers = A string or a cell array of strings defining the ticker symbol(s) to fetch.
% date_start = A string representing the start date of time series with format 'yyyy-mm-dd'.
% date_end = A string representing the end date of time series with format 'yyyy-mm-dd'.
%
% [OUTPUT]
% data = If a single ticker is provided the function returns a table, otherwise a cell array of tables is returned. Each table is structured as a t-by-6 matrix containing the following time series:
%   - Date (numeric observation dates)
%   - Open (opening prices)
%   - High (highest prices)
%   - Low (lowest prices)
%   - Close (closing prices)
%   - Return (log returns)

function data = fetch_data(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('tickers',@(x)validateattributes(x,{'cell' 'char'},{'vector' 'nonempty'}));
        ip.addRequired('date_start',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1,NaN]}));
        ip.addRequired('date_end',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1,NaN]}));        
    end

    ip.parse(varargin{:});
    
    ipr = ip.Results;
    [tickers,date_start,date_end] = validate_input(ipr.tickers,ipr.date_start,ipr.date_end);
    
    nargoutchk(1,1);

    data = fetch_data_internal(tickers,date_start,date_end);

end

function data = fetch_data_internal(tickers,date_start,date_end)

    tickers_len = length(tickers);

    date_origin = datenum(1970,1,1);
    date_start = (datenum(date_start,'yyyy-mm-dd') - date_origin) * 86400;
    date_end = (datenum(date_end,'yyyy-mm-dd') - date_origin) * 86400;

    url = ['https://query1.finance.yahoo.com/v8/finance/chart/%TICKER%?symbol=%TICKER%&period1=' num2str(date_start) '&period2=' num2str(date_end) '&interval=1d'];

    data = cell(tickers_len,1);
    
    bar = waitbar(0,'Fetching data from Yahoo! Finance...');
    e = [];
    
    try

        for i = 1:tickers_len
            ticker = tickers{i};
            
            response = webread(strrep(url,'%TICKER%',ticker));
            response_d = response.chart.result.timestamp;
            response_o = response.chart.result.indicators.quote.open;
            response_h = response.chart.result.indicators.quote.high;
            response_l = response.chart.result.indicators.quote.low;
            response_c = response.chart.result.indicators.quote.close;
            response_ac = response.chart.result.indicators.adjclose.adjclose;

            scale = response_ac ./ response_c;

            date = (response_d ./ 86400) + date_origin;
            open = response_o .* scale;
            high = response_h .* scale;              
            low = response_l .* scale;
            cls = response_c .* scale;
            ret = [NaN; diff(log(response_c))];

            data{i} = table(date,open,high,low,cls,ret,'VariableNames',{'Date' 'Open' 'High' 'Low' 'Close' 'Return'});

            waitbar((i / tickers_len),bar);
        end
        
         waitbar(1,bar);

    catch e
    end
    
    try
        delete(bar);
    catch
    end
    
    if (~isempty(e))
        rethrow(e);
    end
    
    if (tickers_len == 1)
        data = data{1};
    end

end

function [tickers,date_start,date_end] = validate_input(tickers,date_start,date_end)

    if (ischar(tickers))
        tickers = {tickers};
    else
        if (~iscellstr(tickers) || any(cellfun(@length,tickers) == 0) || any(cellfun(@(x)size(x,1),tickers) ~= 1)) %#ok<ISCLSTR>
            error(['The value of ''tickers'' is invalid.' newline() 'Expected input to be a cell array of non-empty character vectors.']);
        end
        
        if (numel(unique(tickers)) ~= numel(tickers))
            error(['The value of ''tickers'' is invalid.' newline() 'Expected input to be contain only unique character vectors.']);
        end
    end

    try
        dn_start = datenum(date_start,'yyyy-mm-dd');
        check = datestr(dn_start,'yyyy-mm-dd');

        if (~isequal(check,date_start))
            error(['The value of ''date_start'' is invalid.' newline() 'Expected input to be a valid date with format ''yyyy-mm-dd''.']);
        end
    catch e
        rethrow(e);
    end

    try
        dn_end = datenum(date_end,'yyyy-mm-dd');
        check = datestr(dn_end,'yyyy-mm-dd');

        if (~isequal(check,date_end))
            error(['The value of ''date_end'' is invalid.' newline() 'Expected input to be a valid date with format ''yyyy-mm-dd''.']);
        end
    catch e
        rethrow(e);
    end
    
    if (dn_start > dn_end)
        error('The date defined by the ''date_start'' parameter must preceed by one defined by the ''date_end'' parameter.');
    end

    if ((dn_end - dn_start) < 30)
        error('There must be a delay of least 30 days between the date defined by the ''date_start'' parameter and the one defined by the ''date_end'' parameter.');
    end
    
end
