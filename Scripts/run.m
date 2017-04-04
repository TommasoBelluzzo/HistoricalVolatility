warning off all;

clearvars;
clc;
close all;

analyse_volatility('YAHOO/JPM',2010,2017,'YZ');
compare_estimators('YAHOO/JPM',2010,2017,90);
