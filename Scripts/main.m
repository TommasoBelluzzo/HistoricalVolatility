data = fetch_data('key','GOOG/NYSE_JPM','2013-01-01','2013-12-31');

vol1 = estimate_volatility(data{1},'CC',30,0);
vol2 = estimate_volatility(data{1},'RS',30,0);

dates = datenum(data{1}.Date);

figure;
plot(dates,vol1);

figure;
plot(dates,vol2);
