/*FactSet Fund Characteristics*/

/*This Script calculates quarterly FactSet fund portfolio characteristics*/

/*Variables include */
/*1. Total and subportfolio AUM by investment destination, total and sub number of securities/firms by investment destination
  2. Country, region, global institution labels a la Bartram et al(2015)
  3. Home bias and country bias
  4. Portfolio HHI
  5. Active share
  6. Institution-security level portfolio concentration (Prado et al 2016, RFS)
  7. Churn ratio
  8. Institution-security level investment horizon*/

/*Including institution-quarter observation filtered a la Camanho et al (2022)*/
/*Author: Lucie Lu, lucie.lu@unimelb.edu.au*/

/*#0. Preamble: include auxiliary tables*/
* creates dual listed companies, institutional type tables, the list of countries to be considered (MSCI ACWI + Luxembourg (LU));
options dlcreatedir;
libname factset ('S:/factset/own_v5','S:/factset/common');

libname fswork 'S:/FSWORK/';
libname sasuser '~/sasuser.v94';
%include 'D:/factset_holdings/auxiliaries2023.sas';
%include 'D:/factset_holdings/functions.sas';
%let exportfolder=D:/jmp/; 


/*#1A. AUM*/
/*Check distribution*/

proc sql;
create table fswork.fund_aum as
select factset_fund_id, quarter, 
sum(dollarholding) as AUM
from fswork.v1_holdingsmf
group by factset_fund_id, quarter;



proc sql;
create table fswork.fund_totalmktcap as 
select a.factset_fund_id,a.quarter,
sum(own_mktcap) as totalmktcap
from fswork.v1_holdingsmf a, fswork.sec_mktcap b 
where a.fsym_id=b.fsym_id
and a.quarter=b.quarter
and own_mktcap gt 0
group by a.factset_fund_id, a.quarter;


/*Fund portfolio weights*/

proc sql;
create table fund_weight as
select  a.quarter, a.factset_fund_id, a.fsym_id,  a.dollarholding, io_sec, io_firm,
		a.dollarholding/aum as weight, b.aum, adj_holding, a.adj_price 

from fswork.v1_holdingsmf a, fswork.fund_aum b
where  a.factset_fund_id=b.factset_fund_id
and a.quarter=b.quarter;

proc sql;
create table fund_weight as 
select a.*, b.totalmktcap
from fund_weight a, fswork.fund_totalmktcap b
where a.factset_fund_id=b.factset_fund_id
and a.quarter=b.quarter;
quit;

proc sql;
create table fswork.fund_weight as 
select a.*,  own_mktcap/totalmktcap as mktweight
from fund_weight a, fswork.sec_mktcap b
where a.fsym_id=b.fsym_id
and a.quarter=b.quarter;
quit;

proc sort data=fswork.fund_weight nodupkey; by factset_fund_id fsym_id quarter;run;


/*#4. HHI index of all funds*/
proc sql;
create table fswork.fund_hhi as 
select quarter, factset_fund_id, sum(weight**2) as hhi
from fswork.fund_weight
group by quarter, factset_fund_id;


proc univariate data=fswork.fund_hhi;
var hhi;
histogram;
run;


/*#5. Activeness of all institutions*/
proc sql;
create table fswork.fund_activeness as 
select  quarter,factset_fund_id, sum(abs(weight-mktweight))/2 as activeshare
from fswork.fund_weight a 
group by quarter,factset_fund_id;
quit; 


proc univariate data=fswork.fund_activeness;
var activeshare;
histogram;
run;

