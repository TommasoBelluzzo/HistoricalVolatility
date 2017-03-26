function data = fetch_data(key,tkr,date_beg,date_end)

    if (ischar(tkr))
        tkr = {tkr};
    end
    
    tkr_len = length(tkr);
    data = cell(tkr_len,1);
    
    bar = waitbar(0,'Fetching data from Quandl...');
    
    try
        Quandl.auth(key);

        for i = 1:tkr_len
            tkr_cur = tkr{i};

            [ts,head] = Quandl.get(tkr_cur,'type','data','start_date',date_beg,'end_date',date_end);
            ts = flipud(ts);
            head = regexprep(head,'\s','');
            
            ts_len = size(ts,1);
            head_len = length(head);
            
            if (head_len < 4)
                throw(MException('fetch_data:HeadersLength','missing time series for ticker %s',tkr_cur));
            end
            
            ts_fin = array2table(zeros(ts_len,6),'VariableNames',{'Date' 'Open' 'High' 'Low' 'Close' 'Returns'});
            ts_add = 0;
            
            for j = 1:length(head)
                switch head{j}
                    case 'Date'
                        ts_fin.Date = datestr(ts(:,j),'yyyy-mm-dd');
                        ts_add = ts_add + 1;
                    case 'Open'
                        ts_fin.Open = ts(:,j);
                        ts_add = ts_add + 1;
                    case 'High'
                        ts_fin.High = ts(:,j);
                        ts_add = ts_add + 1;
                    case 'Low'
                        ts_fin.Low = ts(:,j);
                        ts_add = ts_add + 1;
                    case 'Close'
                        ts_j = ts(:,j);
                        ts_fin.Close = ts_j;
                        ts_fin.Returns = [0; diff(log(ts_j))];
                        ts_add = ts_add + 2;
                end
            end

            if (ts_add < 6)
                throw(MException('fetch_data:HeadersLength','missing time series for ticker %s',tkr_cur));
            end
            
            data{i,1} = ts_fin;

            waitbar((i / tkr_len),bar);
        end
        
        close(bar);
    catch e
        close(bar);
        
        id = e.identifier;
        
        if (strfind(id,'fetch_data:'))
            error(['Error in ' id ': ' e.message '.']);
        else
            error(['Error in ' id '.']);
        end
    end

end
