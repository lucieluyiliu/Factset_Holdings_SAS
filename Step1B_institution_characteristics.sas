/*FactSet Institution Characteristics*/

/*This Script calculates quarterly FactSet institution portfolio characteristics*/

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

/*Augmented security-level holding with institution and security label*/

/*Not sure whether should do NA, EU, and Asia Pacific + others instead*/

/*2024-07-12 add io to this table*/
proc sql;
create table fswork.v1_holdingsall_aug as 
select a.quarter, a.factset_entity_id, a.fsym_id, io_sec, io_firm, dollarholding, 
adj_holding, adj_price,
c.iso_country as sec_country,
d.iso_country as inst_country,
e.isem,
case when f.region='North America' then 'North America'
/*when inst_country='GB' then 'UK'*/
when f.region ='Europe' then 'Europe' /*2024-05-29: Merge US and Canada into NA, no longer differentiate UK from European*/
else 'Others' end as inst_origin, 
case when sec_country=inst_country then 1 else 0 end as is_dom,
case when e.isem='DM' then 1 else 0 end as is_dm,
case when e.isem='EM' then 1 else 0 end as is_em,
case when e.isem='FM' then 1 else 0 end as is_fm 
from fswork.v1_holdingsall a,
fswork.own_basic b,
factset.edm_standard_entity c,
factset.edm_standard_entity d, 
ctry e, ctry f
where a.fsym_id=b.fsym_id
and b.factset_entity_id=c.factset_entity_id
and a.factset_entity_id=d.factset_entity_id
and sec_country=e.iso
and inst_country=f.iso;


/*#1A. AUM*/
/*Check distribution*/

proc sql;
create table fswork.inst_aum as
select factset_entity_id, quarter, inst_origin,
sum(dollarholding) as AUM,
sum(dollarholding*is_dom) as AUM_dom,
sum(dollarholding*(1-is_dom)*is_dm) as AUM_dm,
sum(dollarholding*(1-is_dom)*is_em) as AUM_em,
sum(dollarholding*(1-is_dom)*is_fm) as AUM_fm,
sum(dollarholding*(1-is_dom)) as AUM_for
from fswork.v1_holdingsall_aug
group by factset_entity_id, quarter, inst_origin;

/*Distribution of AUM EMs*/
proc sort data=fswork.inst_aum; by inst_origin; run;

proc univariate data=fswork.inst_aum;
var aum_em;
by inst_origin;
histogram;
run;

/*#1B. Number of stocks in their portfolio*/ 

proc sql;
create table fswork.inst_nsecurities as
select factset_entity_id, quarter, inst_origin,
sum(1) as n,
sum(is_dom) as n_dom,
sum((1-is_dom)*is_dm) as n_dm,
sum((1-is_dom)*is_em) as n_em,
sum((1-is_dom)*is_fm) as n_fm,
sum((1-is_dom)) as n_for
from fswork.v1_holdingsall_aug
group by factset_entity_id, quarter, inst_origin;

proc sort data=fswork.inst_nsecurities nodupkey; by factset_entity_id quarter; run;

proc sort data=fswork.inst_nsecurities; by inst_origin; run;

/*Most do not have foreign em investment*/
proc univariate data=fswork.inst_nsecurities;
var n_em;
by inst_origin;
histogram;
run;

/*#1C. Number of firms in their portfolio*/ 

proc sql;
create table fswork.inst_nfirms as
select a.factset_entity_id, quarter, inst_origin,
sum(1) as n,
sum(is_dom) as n_dom,
sum((1-is_dom)*is_dm) as n_dm,
sum((1-is_dom)*is_em) as n_em,
sum((1-is_dom)*is_fm) as n_fm,
sum((1-is_dom)) as n_for
from fswork.v1_holdingsall_aug a, fswork.principal_security b
where a.fsym_id=b.fsym_id
group by a.factset_entity_id, quarter, inst_origin;

/*Most do not have foreign em investment*/
proc sort data=fswork.inst_nfirms; by inst_origin; run;

proc univariate data=fswork.inst_nfirms;
var n_em;
by inst_origin;
histogram;
run;


/*country allocation of investors*/
proc sql; 
create table fswork.inst_country_weight as 
select a.factset_entity_id, a.quarter, 
int(a.quarter/100) as year,
sum(a.dollarholding)/aum as ctry_weight, inst_country, sec_country, 
is_dom
from fswork.v1_holdingsall_aug a,  fswork.inst_aum b
where a.factset_entity_id=b.factset_entity_id
and aum ne 0
and a.quarter=b.quarter
group by a.factset_entity_id, a.quarter, aum, inst_country, sec_country, is_dom;

proc sort data=fswork.inst_country_weight nodupkey; by factset_entity_id quarter sec_country;run;


/*#2A. Region weight and classify investors into Global, regional and local*/

proc sql; 
create table fswork.inst_region_weight as 
select a.factset_entity_id, a.quarter, sum(a.dollarholding)/aum as region_weight, region

from fswork.v1_holdingsall_aug a, fswork.inst_aum b, ctry c
where aum ne 0
and a.factset_entity_id=b.factset_entity_id
and a.quarter=b.quarter
and a.sec_country=c.iso
group by a.factset_entity_id, a.quarter, aum,  region;

proc sort data=fswork.inst_region_weight nodupkey; by factset_entity_id quarter region;run;

proc sql; select distinct region from ctry;


/*classify entity and funds by their scope*/

/*Institution level*/
proc sql;
create table fswork.ctryinst as 
select 
a.factset_entity_id, a.quarter,a.sec_country, a.ctry_weight, b.maxweight as maxctryweight,
maxweight ge 0.9 as iscountry
from fswork.inst_country_weight a, 
(select max(ctry_weight) as maxweight, quarter,factset_entity_id from fswork.inst_country_weight  group by factset_entity_id, quarter ) b
where a.ctry_weight=b.maxweight 
and a.factset_entity_id=b.factset_entity_id 
and a.quarter=b.quarter;

proc sort data=fswork.ctryinst nodupkey; by factset_entity_id quarter; run;



proc sql;
create table fswork.regioninst as 
select 
a.factset_entity_id, a.quarter,a.region, b.maxweight as maxregionweight,
b.maxweight ge 0.8 and not iscountry as isregion
from fswork.inst_region_weight a, (select max(region_weight) as maxweight, quarter,factset_entity_id from fswork.inst_region_weight group by factset_entity_id, quarter ) b,
fswork.ctryinst c
where a.region_weight=b.maxweight 
and a.factset_entity_id=b.factset_entity_id 
and a.factset_entity_id=c.factset_entity_id
and a.quarter=b.quarter
and a.quarter=c.quarter;

proc sort data=fswork.regioninst nodupkey; by factset_entity_id quarter;run;

/*A table that contains global country indicator, its maxim country allocation and its maximum region allocation*/

proc sql;
create table fswork.inst_isglobal as 
select a.quarter, a.factset_entity_id, aum, sec_country, 
case when iscountry is not null then iscountry else 0 end as iscountry, 
maxctryweight
from fswork.inst_aum a 
left join fswork.ctryinst b 
on(a.factset_entity_id=b.factset_entity_id and a.quarter=b.quarter);


proc sql;
create table fswork.inst_isglobal as 
select  a.quarter, a.factset_entity_id, aum, iscountry, sec_country, maxctryweight, region,
case when isregion is not null then isregion else 0 end as isregion,
maxregionweight
from fswork.inst_isglobal a left join fswork.regioninst b on(a.factset_entity_id=b.factset_entity_id and a.quarter=b.quarter);

proc sort data=fswork.inst_isglobal nodupkey; by quarter factset_entity_id;run;

proc sql;
alter table fswork.inst_isglobal add isglobal num;

proc sql;
update fswork.inst_isglobal
set isglobal=1-iscountry-isregion;

/*add investor country */
proc sql;
create table fswork.inst_isglobal as 
select a.*, b.iso_country as inst_country
from fswork.inst_isglobal a, factset.edm_standard_entity b 
where a.factset_entity_id=b.factset_entity_id;

proc sql; select max(quarter) from fswork.inst_isglobal;

/*PROC sql;*/
/*create table test as select * FROM fswork.inst_isglobal WHERE factset_entity_id='000BJX-E' order by quarter;*/

/*Check who are the largest global institutions by end of 2022 and what is their maximum country and region weight*/
proc sql; 
create table fswork.institutiontype2023 as 
select  a.factset_entity_id, b.entity_proper_name,
case when iscountry=1 then 'ctry fund'
when isregion=1 then 'region fund'
else 'global fund' end as insttype, inst_country, sec_country, maxctryweight, region, maxregionweight, aum 
from fswork.inst_isglobal a, factset.edm_standard_entity b
where a.factset_entity_id=b.factset_entity_id
and a.quarter=202304
order by calculated insttype, aum desc;


/*What are the biggest country, region and global institution from each country, for sanity check*/
proc sql; 
create table fswork.max_inst_iso_2023 as 
select a.factset_entity_id, a.entity_proper_name, a.aum, a.inst_country, a.insttype, a.sec_country, a.maxctryweight, a.region, a.maxregionweight
from fswork.institutiontype2023 a, 
(select max(aum) as maxaum, inst_country, insttype from fswork.institutiontype2023 group by inst_country, insttype) b
where a.inst_country=b.inst_country
and a.insttype=b.insttype
and a.aum=b.maxaum
order by inst_country, insttype;


/*proportion of number of global institutions by year*/
/*About 60% of institutions are country funds, 20% are region, and 20% are global*/
proc sql; 
create table inst_num_prop as
select floor(quarter/100) as year, mean(iscountry) as ctryprop, 
mean(isregion) as regionprop, 
mean(isglobal) as globalprop 
from fswork.inst_isglobal
where mod(quarter,100)=4
group by calculated year
order by calculated year desc;

/*how much AUM are global funds?*/
/*in terms of AUM, global has increased and local has decreased*/
proc sql;
create table inst_aum_prop as 
select floor(quarter/100) as year, sum(iscountry*aum)/sum(aum) as countryfundprop, 
sum(isregion*aum)/sum(aum) as regionfundprop,
sum(isglobal*aum)/sum(aum) as isglobalfundprop
/* sum(isnonglobalfund*aum)/sum(aum) as isnonglobalfundprop, */
from fswork.inst_isglobal 
group by calculated year
order by calculated year desc;


/*2024-09-02 I stopped here*/

/*2B.Home bias*/

/*import country market portfolio weight Datastream+Worldscope*/
/*Assign country using domicile location*/
proc import datafile= 'D:/factset_holdings/ctry_mktcap_weight.csv'
        out=fswork.mktcap_share
        dbms=csv
        replace;


/*Import country market portfolio weight CRSP+Compustat*/
/*Assign country using listing location*/
/*proc import datafile= 'S:/FSWORK/ctry_weight_compustat.csv'*/
/*        out=fswork.ctry_weight_compustat*/
/*        dbms=csv*/
/*        replace;*/


proc sql;
create table fswork.inst_homebias as 
select a.factset_entity_id,a.quarter, a.year, inst_country,
sum(ctry_weight*is_dom) as homeweight,
calculated homeweight-weight as homebias,
(calculated homeweight-weight)/(1-weight) as homebias_norm,
calculated homeweight-weight_float as homebias_float,
(calculated homeweight-weight_float)/(1-weight_float) as homebias_floatnorm

from fswork.inst_country_weight a,
fswork.mktcap_share b,
ctry c
where a.inst_country=c.iso
and c.iso3=b.iso
and a.year=b.year
group by factset_entity_id, a.quarter, a.year, inst_country, weight, weight_float;
quit;

proc sort data=fswork.inst_homebias nodupkey; by factset_entity_id quarter; run;


/*#2C. Foreign bias*/

/*2024-01-21: add foreign bias calculation there are two ways Bekaert and Wang (2009) or Chen et al(2005)*/    
/*Bekaert and Wang normalized foreign bias*/
/*This includes normalized domestic bias for domestic holdings*/    
proc sql;
create table fswork.inst_foreignbias as 
select a.factset_entity_id,a.quarter, a.year, inst_country, sec_country,
case when ctry_weight>weight then (ctry_weight-weight)/(1-weight)
when ctry_weight<weight then (ctry_weight-weight)/weight
end as foreign_bias

from fswork.inst_country_weight a,
fswork.mktcap_share b,
ctry c
where a.sec_country=c.iso
and c.iso3=b.iso
and a.year=b.year;
quit;


/*#4. Active share and HHI*/

/*2024-03-17: do not exclude AD at the security-level to include holdings in both EQ and AD*/

proc sql;
create table fswork.inst_totalmktcap as 
select a.factset_entity_id,a.quarter,
sum(own_mktcap) as totalmktcap
from fswork.v1_holdingsall a, fswork.sec_mktcap b 
where a.fsym_id=b.fsym_id
and a.quarter=b.quarter
and own_mktcap gt 0
group by a.factset_entity_id, a.quarter;

/*Institution portfolio weights*/

proc sql;
create table fswork.inst_weight as
select  a.quarter, a.factset_entity_id, a.fsym_id,  a.dollarholding, io_sec, io_firm,
		a.dollarholding/aum as weight, 
         own_mktcap/totalmktcap as mktweight, 
         aum, adj_holding, a.adj_price, 
		inst_country, sec_country, e.entity_sub_type

from fswork.v1_holdingsall_aug a, fswork.inst_aum b, fswork.inst_totalmktcap c, fswork.sec_mktcap d,
factset.edm_standard_entity e
where  a.factset_entity_id=b.factset_entity_id
and a.quarter=b.quarter
and a.factset_entity_id=c.factset_entity_id
and a.quarter=c.quarter
and a.fsym_id=d.fsym_id
and a.quarter=d.quarter
and a.factset_entity_id=e.factset_entity_id;
quit;


proc sort data=fswork.inst_weight nodupkey; by factset_entity_id fsym_id quarter;run;

/*#4. HHI index of all institutions*/
proc sql;
create table fswork.inst_hhi as 
select quarter, factset_entity_id, sum(weight**2) as hhi
from fswork.inst_weight
group by quarter, factset_entity_id;


proc univariate data=fswork.inst_hhi;
var hhi;
histogram;
run;

/*#5. Activeness of all institutions*/
proc sql;
create table fswork.inst_activeness as 
select  quarter,entity_sub_type, sum(abs(weight-mktweight))/2 as activeshare, 
factset_entity_id, inst_country
from fswork.inst_weight a 
group by quarter,factset_entity_id,entity_sub_type, inst_country;
quit; 


proc univariate data=fswork.inst_activeness;
var activeshare;
histogram;
run;

/*#6. Portfolio concentration at institution-security level a la Prado (2016, RFS)*/

proc sql;
create table fswork.inst_concentration as 
select a.factset_entity_id, a.fsym_id, a.quarter, weight-avg_weight as conc
from fswork.inst_weight a, 
(select factset_entity_id, quarter, mean(weight) as avg_weight
from fswork.inst_weight
group by factset_entity_id, quarter)b 
where a.factset_entity_id=b.factset_entity_id
and a.quarter=b.quarter;


/*#7. Churn Ratio*/

proc sql;
create table fswork.inst_churn as 
select a.quarter, a.factset_entity_id, a.fsym_id,
a.adj_holding as nshares,
a.adj_price as price,
b.adj_holding as nshares_lag,
b.adj_price as price_lag,
abs((a.adj_holding-b.adj_holding)*a.adj_price) as trade,
abs((a.adj_holding>b.adj_holding)*(a.adj_holding-b.adj_holding)*a.adj_price) as trade_buy,
abs((a.adj_holding<b.adj_holding)*(a.adj_holding-b.adj_holding)*a.adj_price) as trade_sell,
(a.adj_holding*a.adj_price+b.adj_holding*b.adj_price)/2 as aum 

from fswork.v1_holdingsall a left join fswork.v1_holdingsall b 
on (a.factset_entity_id=b.factset_entity_id
and a.fsym_id=b.fsym_id
and a.quarter=quarter_add(b.quarter,1)) 
where b.adj_holding is not null
and b.adj_holding ne 0
and b.adj_price is not null
order by a.factset_entity_id, a.fsym_id, a.quarter;


proc sql;
create table fswork.inst_churn_ratio as 
select quarter, factset_entity_id,
sum(trade)/sum(aum) as CR, 
min(sum(trade_buy)/sum(aum), sum(trade_sell)/sum(aum)) as CR_adj
from fswork.inst_churn
group by quarter, factset_entity_id;

proc sql;
update fswork.inst_churn_ratio
set cr=2 where cr>2; /*only 196 instances though*/

proc univariate /*spike at 0*/
data=fswork.inst_churn_ratio;
var CR;
histogram;
run;

/*Calculate 4-quarter moving average churn ratio*/
proc sort data=fswork.inst_churn_ratio; by factset_entity_id quarter; run;

proc expand data=fswork.inst_churn_ratio out=fswork.inst_churn_ma method=none;
id quarter;
by factset_entity_id;
convert cr = cr_ma / transout=(movave 4 trimleft 3);
convert cr_adj = cr_adj_ma / transout=(movave 4 trimleft 3);
run;



/*check number of nan CRs*/

proc sql; select sum(cr is null)/sum(1) from fswork.inst_churn_ratio;

proc sql; select sum(cr_adj is null)/sum(1) from fswork.inst_churn_ratio;

proc sql; select sum(cr_ma is null)/sum(1) from fswork.inst_churn_ma;

proc sql; select sum(cr_adj_ma is null)/sum(1) from fswork.inst_churn_ma;

proc univariate 
data=fswork.inst_churn_ratio;
var CR_adj;
histogram;
run;

/*investor characteristics for filtering*/

proc sql;
create table fswork.inst_characteristics as 
select a.factset_entity_id, a.quarter, a.aum, 
b.homebias, b.homebias_norm, b.homebias_float, b.homebias_floatnorm,
c.activeshare, d.cr, d.cr_ma,
d.cr_adj, d.cr_adj_ma, 
n, n_dom, n_for,
hhi, isglobal
from fswork.inst_aum a 
left join fswork.inst_homebias b
on (a.factset_entity_id=b.factset_entity_id and a.quarter=b.quarter)
left join fswork.inst_activeness c
on (a.factset_entity_id=c.factset_entity_id and a.quarter=c.quarter)
left join fswork.inst_churn_ma d 
on (a.factset_entity_id=d.factset_entity_id
and a.quarter=d.quarter)
left join fswork.inst_nsecurities e
on (a.factset_entity_id=e.factset_entity_id 
and a.quarter=e.quarter)
left join fswork.inst_hhi f
on (a.factset_entity_id=f.factset_entity_id
and a.quarter=f.quarter)
left join fswork.inst_isglobal g
on (a.factset_entity_id=g.factset_entity_id
and a.quarter=g.quarter);

    
/*Before filtering, calculate the number of consecutive reports at each level*/

/*Number of consecutive reports*/

/*distinct institution quarterly report*/
proc sql; 
create table fswork.inst_quarter as 
select distinct factset_entity_id, quarter
from fswork.v1_holdingsall
order by factset_entity_id, quarter;


data consecutive_inst;
    set fswork.inst_quarter;
    by factset_entity_id;
    retain consecutive_count 0;
    if first.factset_entity_id then consecutive_count = 1;

    /* Check if the quarters are consecutive */
    if quarter_add(lag(quarter), 1) = quarter then consecutive_count + 1;
    else consecutive_count = 1;
run;



/*Maximum consecutive reports the investor has*/
proc sql; 
create table fswork.consecutive_inst_max as 
select factset_entity_id, max(consecutive_count) as max_consecutive
from consecutive_inst group by factset_entity_id
order by max_consecutive;


proc univariate 
data=fswork.consecutive_inst_max;
var max_consecutive;
histogram;
run;


/*Factset Institutions*/

/*Quarterly frequency*/
/*2024-03-18: 583,801 after 2023 Dec*/
/*2024-09-04: 593,078 by 2023 Dec after update FactSet*/
proc sql; select count(*) from fswork.inst_characteristics;

/*2024-03-18: 300,627 after filtering*/

proc sql;
create table fswork.inst_filtered as 
select a.*, b.*
from fswork.inst_characteristics a,
fswork.factset_entities b,
fswork.consecutive_inst_max c
where a.factset_entity_id=b.factset_entity_id
and a.factset_entity_id=c.factset_entity_id
/*filters*/
and activeshare is not null
and n_dom>5
and n_for>5
and aum>10
and hhi<0.2
and max_consecutive ge 2;


proc univariate /*No spike at 0*/
data=fswork.inst_filtered;
var activeshare;
histogram;
run;


/*#8. Institution-firm level invesetment horizon*/


data fswork.investment_horizon (keep=factset_entity_id fsym_id horizon quarter);
    set fswork.v1_holdingsall;
    by factset_entity_id fsym_id;
    retain horizon 0;
    if first.factset_entity_id and first.fsym_id then horizon = 1;

    /* Check if the quarters are consecutive */
    if quarter_add(lag(quarter), 1) = quarter then horizon + 1;
    else horizon = 1;
run;


proc sort data=fswork.investment_horizon; by factset_entity_id fsym_id quarter; run;


