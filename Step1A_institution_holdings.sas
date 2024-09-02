
/*This script calculates FactSet institution-level portfolio holdings*/
/*Roll-forward mising report*/
/*Aggregate 13F and fund level holdings to FactSet institution level*/

/*Based on the SAS code of Ferreria and Matos (2008), with the following amendments*/
/*1. Add dollarholding based on quarterly IO and market cap*/
/*2. Security-level holdings, ownership at security and firm level, V1 without applying adjustment factor, V2 applies adjustment factor*/

/*Author: Lucie Lu, lucie.lu@unimelb.edu.au*/

* creates dual listed companies, institutional type tables, the list of countries to be considered (MSCI ACWI + Luxembourg (LU));
options dlcreatedir;
libname factset ('S:/factset/own_v5','S:/factset/common');
libname fswork 'S:/FSWORK/';
libname sasuser '~/sasuser.v94';
%include 'D:/factset_holdings/auxiliaries2024.sas';
%include 'D:/factset_holdings/functions.sas';
%let exportfolder=S:/FSWORK/; 


data mic_exchange;
infile 'D:/jmp/mic_exchange.csv' delimiter = ','
          missover DSD  lrecl = 32767
          firstobs = 2;
informat ISO $2. ;
informat MIC_EXCHANGE_CODE $6.;

format ISO $2. ;
format MIC_EXCHANGE_CODE $6.;
INPUT 
ISO$
MIC_EXCHANGE_CODE$;
run;

* ************************************* ;
* User Defined Variables				;
* ************************************* ;
* starting quarter (YYYY0Q);
%let sqtr = 200001;

* ending quarter (YYYY0Q);
%let eqtr = 202304;

* roll forward missing reports (0/1);
%let roll = 1;

*roll 1 - takes a snapshot of the entity's last available report to fill missing reports 
in between two report dates. Each report is valid for 7 quarters;
%let n1 = 7;

*roll 2 - fills missing reports if the most recent report was filed on or after T-3;
%let n2 = 3;

/*#1: subset of qualifying securities*/

* proxy for termination date from security prices table;
proc sql;
create table termination as
select fsym_ID, max(price_date) format=YYMMDD10. as termination_date
from factset.own_sec_prices_eq
group by fsym_ID;

* securities that are defined as Equity or ADR in ownership, or Preferred if defined as PREFEQ in sym_coverage;
/*add exchange information to security table*/
proc sql;
create table equity_secs as
select t1.fsym_id, t1.issue_type, t1.iso_country, t1.fref_security_type, 
t2.iso as ex_country, /*legacy code for security listing information*/
security_name 
from (select * from factset.own_sec_coverage_eq a left join factset.sym_coverage b
on a.fsym_id eq b.fsym_id 
where a.fsym_id in (select distinct fsym_id from factset.own_sec_prices_eq) 
and(a.issue_type in ('EQ','AD') or (issue_type eq 'PF' and b.fref_security_type eq 'PREFEQ'))) t1, 
mic_exchange t2
where t1.mic_exchange_code=t2.mic_exchange_code;



/*add dummies for local stock and depository receipts*/

proc sql;
create table own_basic as
select a.*, b.factset_entity_id, c.termination_date,
case when iso_country=ex_country then 1 else 0 end as islocal,
case when issue_type='AD' then 1 else 0 end as isdr
from equity_secs a, factset.own_sec_entity_eq b, termination c
where a.fsym_id eq b.fsym_id and a.fsym_id eq c.fsym_id;

* updates unadj_own_basic with main company for dual listed entities to combine; 
proc sql;
update own_basic as a
	set factset_entity_id = (
		select b.factset_entity_id from dlc b
		where a.factset_entity_id eq b.dlc_entity_id)
	where  exists (select 1 from dlc b where a.factset_entity_id eq b.dlc_entity_id);

proc sort data=own_basic nodupkeys; by fsym_id ; run;

/*add entity name*/
proc sql;
create table fswork.own_basic as select a.*, b.entity_proper_name 
from own_basic a left join  factset.edm_standard_entity b 
on( a.factset_entity_id=b.factset_entity_id); 

* #2. sample range*/
* starting quarter (YYYY0Q);
%let sqtr = 200001;

%let eqtr = 202304;
* ending quarter (YYYY0Q);
proc sql;
select year(maxdate)*100+qtr(maxdate) into: eqtr
from 
(select max(report_date) as maxdate from factset.own_inst_13f_detail_eq);
quit;

%put &eqtr;

/*#3 Price and market cap procedures*/

* ..................................................................... ;
* most recent price_date within each month								;
* ..................................................................... ;

/*last monthly price*/
proc sql;
create table fswork.prices_historical as
select 	 a.fsym_ID, 
		 year(a.price_date)*100+month(a.price_date) as month,
		 year(a.price_date)*100+qtr(a.price_date) as quarter,
		 case
		  when month(price_date) in (3,6,9,12) then 1
		  else 0
		 end as eoq, 
		 a.adj_shares_outstanding,
		 a.adj_price,
		 a.adj_price*a.adj_shares_outstanding/1000000 as own_mktcap
from	 factset.own_sec_prices_eq a, 
		 (select fsym_ID, year(price_date)*100+month(price_date) as month, max(price_date) as maxdate
			from factset.own_sec_prices_eq
			group by fsym_ID, calculated month) b
where	 (a.fsym_ID = b.fsym_ID and a.price_date = b.maxdate)
order by a.fsym_ID, calculated month;

* ......................................................................................;
* Market Cap Procedure; 
* ......................................................................................;
/*quarterly*/
proc sql;
create table fswork.sec_mktcap as
select fsym_ID, quarter, own_mktcap, adj_price, adj_shares_outstanding
from fswork.prices_historical
where mod(month,100) in (3,6,9,12)
and own_mktcap is not missing;


/*Optional: company-level market cap*/

proc sql;
create table own_mktcap1 as
select a.*, 
b.factset_entity_id, b.issue_type, b.fref_security_type, 
a.adj_price * a.adj_shares_outstanding/1000000 as own_mv, islocal
from factset.own_sec_prices_eq a, fswork.own_basic b
where a.fsym_ID eq b.fsym_ID
and b.issue_type ne 'AD' and b.fref_security_type ne 'TEMP';
/*new filter from Ferreira and Matos that fref_security_type is not TEMP*/
/*Filtert below removed in latest code*/

* exclude securities labeled as "EQ" in ownership but "TEMP" in factset common;
* exclude unilever ADR classified as "EQ";

/*proc sql;*/
/*delete from own_mktcap1 where fsym_id eq 'DXVFL5-S' and price_date ge '30SEP2015'd;*/



proc sql; select count(*) from own_mktcap1;

/*company level monthly mv*/

proc sql;
create table hmktcap as
select factset_entity_id, 
year(price_date)*100+month(price_date) as month,
year(price_date)*100+qtr(price_date) as quarter,
case
	when month(price_date) in (3,6,9,12) then 1
	else 0
end as eoq,  
sum(own_mv) as mktcap_usd,
sum(own_mv*islocal)/calculated mktcap_usd as local_share,
sum(own_mv*(1-islocal))/calculated mktcap_usd as external_share
from own_mktcap1
where factset_entity_id is not missing
group by factset_entity_id, price_date, month, quarter, eoq
having calculated mktcap_usd is not missing and calculated mktcap_usd gt 0;

/* proc sql; */
/* create table hmktcap as */
/* select  factset_entity_id, price_date, month, quarter, eoq, */
/* 		own_mv as mktcap_usd, */
/* 		local_share, */
/* 		external_share */
/* 		 */
/* from own_mktcap */
/* where factset_entity_id is not missing */
/* and calculated mktcap_usd is not missing and calculated mktcap_usd gt 0; */

proc sort data=hmktcap nodupkeys; by factset_entity_id month; run;

proc sql; create table fswork.hmktcap as select * from hmktcap;


/*#4 calculate ownership without adjustment */

* ......................................................................................;
* 13F Reports;
* .....................................................................................;
proc sql;
create table fswork.own_inst_13f_detail as 
select factset_entity_id, fsym_id, report_date, year(report_date)*100+qtr(report_date) as quarter, adj_holding
from factset.own_inst_13f_detail_eq
where calculated quarter between &sqtr and &eqtr;

/*last report date each quarter*/
proc sql;
create table max13f as
select  factset_entity_id, 
		quarter, 
		max(report_date) as maxofdlr format=yymmdd10.
from fswork.own_inst_13f_detail
group by factset_entity_id, quarter;

/*last report each qtr*/
proc sql;
create table aux13f as
select b.*, year(b.report_date)*100+month(b.report_date) as month
from  max13f a, fswork.own_inst_13f_detail b
where a.factset_entity_id eq b.factset_entity_id
and   a.maxofdlr eq b.report_date;


/*here price is the price at the holding month*/
proc sql;
create table fswork.v0_holdings13f as
select t1.factset_entity_id, t1.fsym_ID, t1.quarter, t1.adj_holding, t3.adj_price, t3.adj_shares_outstanding, 
t1.adj_holding / t3.adj_shares_outstanding as io_sec,
(t1.adj_holding*t3.adj_price/1000000) / t4.mktcap_usd as io_firm,
t3.own_mktcap as sec_mv,
t1.adj_holding*t3.adj_price/1000000 as dollarholding  /*for portfolio weight and identifying global institutions*/
from aux13f t1, fswork.own_basic t2, fswork.prices_historical t3, fswork.hmktcap t4
where t1.fsym_ID eq t2.fsym_ID 
and t1.fsym_ID eq t3.fsym_ID 
and t1.month eq t3.month
and t2.factset_entity_id=t4.factset_entity_id
and t1.month=t4.month;


/*Koijen*/

data fswork.v0_holdings13f;
set fswork.v0_holdings13f;
if factset_entity_id in ('0FSVG4-E','000V4B-E') then delete;
run;

/*in case delete erronous entries where holding is larger than security mv*/
data fswork.v0_holdings13f;
set fswork.v0_holdings13f;
if dollarholding gt sec_mv then delete;
run;


proc sql; select max(quarter) from fswork.v0_holdings13f;

* ......................................................................................;
* Mutual Funds;
* .....................................................................................;

proc sql;
create table fswork.own_fund_detail as 
select factset_fund_id, fsym_id, report_date, year(report_date)*100+qtr(report_date) as quarter, adj_holding
from factset.own_fund_detail_eq
where calculated quarter between &sqtr and &eqtr;



/*last report date in each quarter*/
proc sql;
create table maxmf as
select  factset_fund_id, 
		quarter,
		max(report_date) as maxofdlr  format=yymmdd10.
from fswork.own_fund_detail
group by factset_fund_id, quarter;

/*last report in each quarter*/
proc sql;
create table auxmf as
select b.*, year(b.report_date)*100+month(b.report_date) as month
from  maxmf a, fswork.own_fund_detail b
where a.factset_fund_id eq b.factset_fund_id
and   a.maxofdlr eq b.report_date;

/*Here the price is the price of the holding month*/
proc sql;
create table fswork.v0_holdingsmf as
select t1.factset_fund_id, t1.fsym_ID, t1.quarter, t1.adj_holding, t3.adj_price, t3.adj_shares_outstanding, 
t1.adj_holding / t3.adj_shares_outstanding as io_sec,
(t1.adj_holding*t3.adj_price/1000000) / t4.mktcap_usd as io_firm,
t3.own_mktcap as sec_mv,
t1.adj_holding*t3.adj_price/1000000 as dollarholding  /*keep it in case need it for portfolio weight*/
/*2023-06-25: decided to use rolled over io and market cap for portfolio instead*/
from auxmf t1, fswork.own_basic t2, fswork.prices_historical t3,
fswork.hmktcap t4
where t1.fsym_ID eq t2.fsym_ID 
and t1.fsym_ID eq t3.fsym_ID 
and t1.month eq t3.month
and t1.month = t4.month
and t2.factset_entity_id=t4.factset_entity_id;


/*delete outlier*/  
data fswork.v0_holdingsmf;
   set fswork.v0_holdingsmf;
   if factset_fund_id='04B9J7-E' and fsym_id='C7R70B-S' then delete;
run;

data fswork.v0_holdingsmf;
set fswork.v0_holdingsmf;
if dollarholding=. or sec_mv=. then delete;
run;

/*in case delete erronous entries where holding is larger than security mv*/
data fswork.v0_holdingsmf;
set fswork.v0_holdingsmf;
if dollarholding gt sec_mv then delete;
run;


/**#5 imputing missing ownership**/

	
	proc sql;
	create table sym_range as
	select fsym_ID, year(termination_date)*100+qtr(termination_date) as maxofqtr
	from fswork.own_basic;

	proc sql;
	create table rangeofquarters as
	select distinct quarter from fswork.own_inst_13f_detail order by quarter;

	* 13F;
	proc sql;
	create table insts_13f as
	select distinct factset_entity_id from fswork.own_inst_13f_detail order by factset_entity_id;

	proc sql;
	create table insts_13fdates as
	select distinct factset_entity_id, quarter from insts_13f, rangeofquarters order by factset_entity_id, quarter;

	proc sql;
	create table pairs_13f as
	select distinct factset_entity_id, quarter, 1 as has_report from fswork.own_inst_13f_detail order by factset_entity_id, quarter;

	proc sql;
	create table entity_minmax as
	select factset_entity_id, min(quarter) as min_quarter, max(quarter) as max_quarter
	from fswork.own_inst_13f_detail
	group by factset_entity_id;

	proc sql;
	create table roll113f as
	select a.*,
		   case
		   	  when b.has_report is missing then 0
			  else b.has_report
		   end as has_report,
		   c.min_quarter,
		   c.max_quarter as max_quarter_raw,
		   case
		   	  when c.max_quarter >= quarter_add(&eqtr,-&n2) then &eqtr
			  else c.max_quarter
		   end as max_quarter
	from insts_13fdates a
	left join pairs_13f b on a.factset_entity_id eq b.factset_entity_id and a.quarter eq b.quarter
	inner join entity_minmax c on a.factset_entity_id eq c.factset_entity_id;

	proc sql;
	create table roll113f as select * from roll113f where quarter between min_quarter and max_quarter order by factset_entity_id, quarter;

	proc sql;
	create table roll13f as 
	select a.*, b.quarter as last_qtr, (int(a.quarter/100) - int(b.quarter/100))*4 + mod(a.quarter,100) - mod(b.quarter,100) as dif_quarters,
		   case
			  when calculated dif_quarters le &n1 then 1
			  else 0
		   end as valid
	from roll113f a, pairs_13f b
	where a.factset_entity_id eq b.factset_entity_id and b.quarter <= a.quarter
	order by a.factset_entity_id, a.quarter, b.quarter desc;

	/*Remove duplicate keys keep most recent quarter*/
	proc sort data=roll13f nodupkey; by factset_entity_id quarter; run;

	proc sql;
	create table fill_13f as
	select *
	from roll13f
	where has_report eq 0 and valid eq 1;


/*maybe need rollup quantity only not price or value.*/
	proc sql;
	create table inserts_13f as
	select b.factset_entity_id, a.quarter, b.fsym_id, b.adj_holding, b.io_sec, b.io_firm 
	/*rolled up only number of holding and io, not price here maybe this explains churn?*/
	from fill_13f a, fswork.v0_holdings13f b, sym_range c
	where a.factset_entity_id eq b.factset_entity_id and a.last_qtr eq b.quarter
	and b.fsym_id eq c.fsym_id and a.quarter lt c.maxofqtr;
	
/* 	without aggregation, add roll over but do not roll over price */
	proc sql; 
	create table fswork.v1_holdings13f as 

	select factset_entity_id, fsym_ID, quarter, io_sec, io_firm, adj_holding from fswork.v0_holdings13f
			union all corr
	select factset_entity_id, fsym_ID, quarter, io_sec, io_firm, adj_holding from inserts_13f;
	
	proc sort data=fswork.v1_holdings13f nodupkeys; by factset_entity_id fsym_id quarter; run;
	
proc sql; select count(*) from fswork.sec_mktcap;

	/*assume dollar holding=rolled over io times quarter end mktcap*/
	proc sql; 
	create table fswork.v1_holdings13f as 
	select a.factset_entity_id, a.fsym_id, a.quarter, a.adj_holding, b.adj_price,
/* 	a.adj_holding*adj_price/1000000 as valueholding,  */
	io_sec, a.io_firm, a.io_sec*b.own_mktcap as dollarholding
/* 	calculated valueholding-calculated dollarholding as diff */
	from fswork.v1_holdings13f a left join fswork.sec_mktcap b 
	on(a.quarter=b.quarter
	and a.fsym_id=b.fsym_id);

  proc sql;
  select count(*) 
  from fswork.v1_holdings13f
  where dollarholding ne . and dollarholding ne 0;

	
	data fswork.v1_holdings13f;
    set fswork.v1_holdings13f;
    if dollarholding=. or dollarholding=0 then delete;
    run;


	proc sql;   /*roll up 13f to their rollup institutions*/
	create table fswork.v2_holdings13f as
	select t2.factset_rollup_entity_id as factset_entity_id, t1.fsym_id, t1.quarter, adj_price,
	sum(t1.io_sec) as io_sec, 
	sum(t1.io_firm) as io_firm, 
    sum(dollarholding) as dollarholding, 
	sum(adj_holding) as adj_holding
	from fswork.v1_holdings13f t1,
		 factset.own_ent_13f_combined_inst t2
	where t1.factset_entity_id eq t2.factset_filer_entity_id
	group by t2.factset_rollup_entity_id, t1.fsym_id, t1.quarter, adj_price;
	

	
	proc sort data=fswork.v2_holdings13f nodupkeys; by factset_entity_id fsym_id quarter; run;
	
	/*check out here and save aggregated holdings at the institutional level, though not very useful*/

	* Mutual Funds;
	proc sql;
	create table insts_mf as
	select distinct factset_fund_id from fswork.own_fund_detail order by factset_fund_id;

	proc sql;
	create table insts_mfdates as
	select distinct factset_fund_id, quarter from insts_mf, rangeofquarters order by factset_fund_id, quarter;

	proc sql;
	create table pairs_mf as
	select distinct factset_fund_id, quarter, 1 as has_report from fswork.own_fund_detail order by factset_fund_id, quarter;

	proc sql;
	create table fund_minmax as
	select factset_fund_id, min(quarter) as min_quarter, max(quarter) as max_quarter
	from fswork.own_fund_detail
	group by factset_fund_id;

	/*I stopped here*/

	proc sql;
	create table roll1mf as
	select a.*,
		   case
		   	  when b.has_report is missing then 0
			  else b.has_report
		   end as has_report,
		   c.min_quarter,
		   c.max_quarter as max_quarter_raw,
		   case
		   	  when c.max_quarter >= quarter_add(&eqtr,-&n2) then &eqtr
			  else c.max_quarter
		   end as max_quarter
	from insts_mfdates a
	left join pairs_mf b on a.factset_fund_id eq b.factset_fund_id and a.quarter eq b.quarter
	inner join fund_minmax c on a.factset_fund_id eq c.factset_fund_id;

	proc sql;
	create table roll1mf as select * from roll1mf where quarter between min_quarter and max_quarter order by factset_fund_id, quarter;

	proc sql;
	create table rollmf as 
	select a.*, b.quarter as last_qtr, (int(a.quarter/100) - int(b.quarter/100))*4 + mod(a.quarter,100) - mod(b.quarter,100) as dif_quarters,
		   case
			  when calculated dif_quarters le &n1 then 1
			  else 0
		   end as valid
	from roll1mf a, pairs_mf b
	where a.factset_fund_id eq b.factset_fund_id and b.quarter <= a.quarter
	order by a.factset_fund_id, a.quarter, b.quarter desc;

	proc sort data=rollmf nodupkey; by factset_fund_id quarter; run;

	proc sql; select count(*) from rollmf;


	proc sql;
	create table fill_mf as
	select *
	from rollmf
	where has_report eq 0 and valid eq 1;


	proc sql;
	create table inserts_mf as
	select b.factset_fund_id, a.quarter, b.fsym_id, b.adj_holding, b.io_sec, b.io_firm
	from fill_mf a, fswork.v0_holdingsmf b, sym_range c
	where a.factset_fund_id eq b.factset_fund_id and a.last_qtr eq b.quarter
	and b.fsym_id eq c.fsym_id and a.quarter lt c.maxofqtr;


    /*do not rollover price information because legacy price is not useful*/
    proc sql;
    create table fswork.v1_holdingsmf as 
    select factset_fund_id, fsym_ID, quarter, io_sec, io_firm,  adj_holding from fswork.v0_holdingsmf
			union all corr
    select factset_fund_id, fsym_ID, quarter, io_sec, io_firm,  adj_holding from inserts_mf;
    
    proc sort data=fswork.v1_holdingsmf nodupkeys; by factset_fund_id fsym_id quarter; run;


	proc sql; 
	create table fswork.v1_holdingsmf as 
	select a.factset_fund_id, a.fsym_id, a.quarter, a.adj_holding, b.adj_price,
/* 	a.adj_holding*adj_price/1000000 as valueholding,  */
	io_sec, io_firm, a.io_sec*b.own_mktcap as dollarholding
/* 	calculated valueholding-calculated dollarholding as diff */
	from fswork.v1_holdingsmf a left join fswork.sec_mktcap b 
	on( a.quarter=b.quarter
	and a.fsym_id=b.fsym_id);
	
	proc sort data=fswork.v1_holdingsmf nodupkeys; by factset_fund_id fsym_id quarter; run;
	
	proc sql; 
    CREATE TABLE test AS
    SELECT count(*) FROM fswork.v1_holdingsmf 
    WHERE dollarholding ne . AND dollarholding ne 0;

	proc sql; 
    CREATE TABLE test AS
    SELECT count(*) FROM fswork.v1_holdingsmf 
    WHERE dollarholding is not null;


    data fswork.v1_holdingsmf;
    set fswork.v1_holdingsmf;
    if dollarholding=. or dollarholding=0 then delete;
    run;

 
	proc sql;
	create table fswork.v2_holdingsmf as
	select factset_inst_entity_id as factset_entity_id, fsym_ID, quarter, adj_price,
	sum(adj_holding) as adj_holding, 
    sum(io_sec) as io_sec,
	sum(io_firm) as io_firm,
    sum(dollarholding) as dollarholding
	from fswork.v1_holdingsmf t1,
			factset.own_ent_funds t2
	where t1.factset_fund_id eq t2.factset_fund_id
	group by factset_entity_id, fsym_ID, quarter, adj_price;
	
	proc sort data=fswork.v2_holdingsmf nodupkeys; by factset_entity_id fsym_id quarter; run;
	
/*remove zero holdings that are not useful*/

data fswork.v2_holdings13f;
set fswork.v2_holdings13f;
if dollarholding=. or dollarholding=0 then delete;
run;

data fswork.v2_holdingsmf;
set fswork.v2_holdingsmf;
if dollarholding=. or dollarholding=0 then delete;
run;


/*#6 combine 13f and mf*/

proc sql;
create table inst_quarter_mf as
select distinct factset_entity_id, quarter from fswork.v2_holdingsmf;
create table inst_quarter_13f as
select distinct factset_entity_id, quarter from fswork.v2_holdings13f;

proc sql;
create table inst_quarter_mf_only as
select a.factset_entity_id, a.quarter
from inst_quarter_mf a
left join inst_quarter_13f b on (a.factset_entity_id = b.factset_entity_id and a.quarter = b.quarter)
where b.factset_entity_id is missing and b.quarter is missing;

proc sql;
create table inst_quarter_13f_only as
select a.factset_entity_id, a.quarter
from inst_quarter_13f a
left join inst_quarter_mf b on (a.factset_entity_id = b.factset_entity_id and a.quarter = b.quarter)
where b.factset_entity_id is missing and b.quarter is missing;

proc sql;
create table inst_quarter_both as
select a.factset_entity_id, a.quarter
from inst_quarter_mf a, inst_quarter_13f b
where a.factset_entity_id = b.factset_entity_id and a.quarter = b.quarter;

proc sql;  
create table fswork.v1_holdingsall as
select factset_entity_id, fsym_id, quarter, 
max(io_sec) as io_sec, 
max(io_firm) as io_firm,
max(dollarholding) as dollarholding, 
max(adj_holding) as adj_holding,
adj_price

from (
	select factset_entity_id, fsym_id, quarter, io_sec, io_firm, dollarholding, adj_holding, adj_price 
    from fswork.v2_holdings13f

	union all corr

	select b.factset_entity_id, b.fsym_id, b.quarter, b.io_sec, io_firm, b.dollarholding, b.adj_holding, adj_price
	from inst_quarter_mf_only a, fswork.v2_holdingsmf b
	where a.factset_entity_id eq b.factset_entity_id
	and a.quarter eq b.quarter

	union all corr

	select c.factset_entity_id, c.fsym_id, c.quarter, c.io_sec, io_firm, c.dollarholding, c.adj_holding, adj_price
	
	from inst_quarter_both a, fswork.own_basic b, fswork.v2_holdingsmf c
	where b.iso_country ne 'US' and a.factset_entity_id = c.factset_entity_id
	and a.quarter = c.quarter and b.fsym_id = c.fsym_id 
		)
group by factset_entity_id, fsym_id, quarter, adj_price;


proc sort data=fswork.v1_holdingsall nodupkeys; by factset_entity_id fsym_id quarter; run;

/*169177664*/
proc sql; create table count as select count(*) from home.v1_holdingsall;



proc univariate data=fswork.v1_holdingsall;
var io_sec;
run;

/*checkout here save merged table*/


/*Security level Adj_factor: sum across institutions at security level*/

proc sql;
create table fswork.adjfactor_sec as
select fsym_id, quarter, sum(io_sec) as io_sec, max(calculated io_sec, 1) as adjf
from fswork.v1_holdingsall 
group by fsym_id, quarter;
quit;

proc univariate data=home.adjfactor_sec;
var adjf;
run;

/*Firm-level Adj_factor*/
proc sql;
create table fswork.adjfactor_firm as
select b.factset_entity_id as company_id, quarter, sum(io_firm) as io_firm, max(calculated io_firm, 1) as adjf 
from fswork.v1_holdingsall a, fswork.own_basic b 
where a.fsym_id=b.fsym_id
group by company_id, quarter;
quit;

/*Firm level more abnormal*/
proc univariate data=home.adjfactor_firm;
var adjf;
run;


/*Make adjustment to security-level ownership, add firm-information and factset market cap*/
proc sql; 
create table fswork.v2_holdingsall_sec as
select 
a.factset_entity_id, a.fsym_id, 
d.factset_entity_id as company_id, 
a.quarter, 
e.iso_country as inst_country, 
f.iso_country as sec_country, 
e.entity_sub_type,
 a.io_sec as io_unadj,
 a.io_sec/adjf as io,
 adj_holding/adjf as adj_holding,
 dollarholding/adjf as dollarholding
from fswork.v1_holdingsall a, fswork.adjfactor_sec b, fswork.sec_mktcap c, fswork.own_basic d,
factset.edm_standard_entity e, factset.edm_standard_entity f
where a.fsym_id=b.fsym_id
and a.quarter=b.quarter
and a.fsym_id=c.fsym_id
and a.quarter=c.quarter
and a.fsym_id=d.fsym_id
and a.factset_entity_id=e.factset_entity_id
and d.factset_entity_id=f.factset_entity_id
and a.io_sec is not missing
and own_mktcap is not missing
and own_mktcap ne 0
and d.factset_entity_id is not missing;


proc sort data=fswork.v2_holdingsall_sec nodupkey; by factset_entity_id quarter fsym_id; run;


/*Aggregate across securities at the firm_level, add instiution label*/

proc sql;
create table fswork.v1_holdingsall_firm as
select  a.factset_entity_id, b.factset_entity_id as company_id, a.quarter, 
		c.iso_country as inst_country, d.iso_country as sec_country, c.entity_sub_type,
		sum(a.io_firm) as io, sum(dollarholding) as dollarholding, 
        cat_institution,
		case
	      when f.region eq 'North America' then 'North America'
/*		  when c.iso_country eq 'GB' then 'UK' 2024-05-29: merge UK and Europe*/
		  when f.region eq 'Europe' then 'Europe'
		  else 'Others'
    end as inst_origin
from fswork.v1_holdingsall a, fswork.own_basic b,
 factset.edm_standard_entity c, 
 factset.edm_standard_entity d,
 inst_type e,
 fswork.ctry f
where a.fsym_ID eq b.fsym_ID 
and   a.factset_entity_id eq c.factset_entity_id
and   b.factset_entity_id eq d.factset_entity_id
and   b.factset_entity_id is not missing 
and a.io_firm is not missing
and c.entity_sub_type=e.entity_sub_type
and c.iso_country=f.iso
and c.entity_sub_type is not null
group by a.factset_entity_id, b.factset_entity_id, 
a.quarter, c.iso_country, d.iso_country, c.entity_sub_type, cat_institution, inst_origin;


/*Apply firm-level adjustment factor to V2 */

proc sql;
create table fswork.v2_holdingsall_firm as 
select a.factset_entity_id, a.company_id, a.quarter,a.inst_country, a.sec_country, 
a.entity_sub_type,
a.io as io_unadj,
adjf,
a.io/adjf as io, 
a.dollarholding/adjf as dollarholding, a.cat_institution, a.inst_origin
from fswork.v1_holdingsall_firm a, fswork.adjfactor_firm b 
where a.company_id=b.company_id 
and a.quarter=b.quarter;


/*Find principal securities*/

proc sql;
create table fswork.principal_security as
select *
from factset.sym_coverage a
left join factset.own_sec_entity_eq b on a.fsym_id eq b.fsym_id
where b.factset_entity_id in (select distinct company_id from fswork.v2_holdingsall_firm)
and b.factset_entity_id is not missing
and a.fsym_id eq a.fsym_primary_equity_id
order by b.factset_entity_id;

