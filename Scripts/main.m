data = fetch_data('MyKey','GOOG/NYSE_JPM','2013-01-01','2013-12-31');
data = data{1};

vol1 = estimate_volatility(data,'CC',30,0);
vol2 = estimate_volatility(data,'RS',30,0);

dates = datenum(data{1}.Date);

figure;
plot(dates,vol1);

figure;
plot(dates,vol2);
