% [INPUT]
% tkrs     = A string or a vector of strings representing the ticker symbols.
% date_beg = A string representing the start date in the format "yyyy-mm-dd".
% date_end = A string representing the end date in the format "yyyy-mm-dd".
%
% [OUTPUT]
% data     = If a single ticker symbol is provided, the function returns a t-by-6 table with the following time series:
%             - Date (the dates of the observations)
%             - Open (the opening prices)
%             - High (the highest prices)
%             - Low (the lowest prices)
%             - Close (the closing prices)
%             - Return (the log returns)
%            Otherwise, a column vector of t-by-6 tables (as described above) is returned.
%
% [NOTE]
% The 'key' parameter passed to the Quandl.auth() call must be replaced with a valid authentication key.

function data = fetch_data(varargin)

    persistent p;

    if (isempty(p))
        p = inputParser();
        p.addRequired('tkrs',@(x)validateattributes(x,{'cell','char'},{'vector','nonempty'}));
        p.addRequired('date_beg',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        p.addRequired('date_end',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));        
    end

    p.parse(varargin{:});
    res = p.Results;
    tkrs = res.tkrs;
    date_beg = res.date_beg;
    date_end = res.date_end;

    try
        num_beg = datenum(date_beg,'yyyy-mm-dd');
        check = datestr(num_beg,'yyyy-mm-dd');

        if (~isequal(check,date_beg))
            throw(MException('',''));
        end
    catch
        error('Invalid start date specified.');
    end

    try
        num_end = datenum(date_end,'yyyy-mm-dd');
        check = datestr(num_end,'yyyy-mm-dd');

        if (~isequal(check,date_end))
            throw(MException('',''));
        end
    catch
        error('Invalid end date specified.');
    end

    if ((num_end - num_beg) < 30)
        error('The start date must be anterior to the end date by at least 30 days.');
    end

    data = fetch_data_internal(tkrs,date_beg,date_end);

end

function data = fetch_data_internal(tkrs,date_beg,date_end)

    if (ischar(tkrs))
        tkrs = {tkrs};
    end
     
    tkrs_len = length(tkrs);
    
    data = cell(tkrs_len,1);
    tkr_dbs = cell(tkrs_len,1);
    
    bar = waitbar(0,'Fetching data from Quandl...');
    
    try
        Quandl.auth('key');

        for i = 1:tkrs_len
            tkr = tkrs{i};
            tkr_spl = strsplit(tkr,'/');
            tkr_db = tkr_spl{1};

            switch tkr_db
                case 'GOOG'
                    cols = {'Date' 'Open' 'High' 'Low' 'Close'};
                    cols_len = length(cols);
                case 'WIKI'
                    cols = {'Date' 'Adj. Open' 'Adj. High' 'Adj. Low' 'Adj. Close'};
                    cols_len = length(cols);
                case 'YAHOO'
                    cols = {'Date' 'Open' 'High' 'Low' 'Close' 'Adjusted Close'};
                    cols_len = length(cols);
                otherwise
                    error(['The database ' tkr_db ' is not supported.']);
            end
            
            [ts,head] = Quandl.get(tkr,'type','data','start_date',date_beg,'end_date',date_end);
            
            if (length(head) < cols_len)
                error(['Missing time series for ticker ' tkr '.']);
            end

            ts = flipud(ts(:,ismember(head,cols)));
            ts_len = size(ts,1);

            if (ts_len < cols_len)
                error(['Missing time series for ticker ' tkr '.']);
            end
            
            if (strcmp(tkr_db,'YAHOO'))
                ratio = ts(:,6) ./ ts(:,5);
                ts(:,2:5) = ts(:,2:5) .* repmat(ratio,1,4);
            end
            
            ts(:,6) = [NaN; diff(log(ts(:,5)))];
            data{i} = array2table(ts,'VariableNames',{'Date' 'Open' 'High' 'Low' 'Close' 'Return'});

            tkr_dbs{i} = tkr_db;
            
            waitbar((i / tkrs_len),bar);
        end

        if (length(unique(tkr_dbs)) ~= 1)
            warning('For a matter of coherence, it is recommended to retrieve all the data from a single Quandl database.');
        end
        
        close(bar);
        
        if (tkrs_len == 1)
            data = data{1};
        end
    catch e
        close(bar);
        rethrow(e);
    end

end