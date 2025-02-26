/*This script compiles fund information from FactSet and security identifiers*/
/*1. Funds and FactSet entity identifiers*/
/*2. Security identifiers, to be ran after Step1A*/

/*Author: Lucie Lu, lucie.lu@unimelb.edu.au*/
/*Based on sample code from David Schumacher*/

options dlcreatedir;

libname factset ('S:/factset/own_v5','S:/factset/common');

libname fswork 'S:\FSWORK\';

libname sasuser '~/sasuser.v94';

%include 'D:\factset_holdings\auxiliaries2024.sas';

proc sql; create table fswork.ctry as select * from ctry;


data fswork.funds;

      set factset.own_ent_funds (drop= PE_RATIO PB_RATIO DIVIDEND_YIELD SALES_GROWTH PRICE_MOMENTUM RELATIVE_STRENGTH BETA CURRENT_REPORT_DATE TURNOVER_LABEL);

run;

* merge in parent info, fund name,...;

proc sql;

      create table fswork.funds as select a.*, b.fs_ultimate_parent_entity_id

      from fswork.funds a left join factset.edm_standard_entity_structure b

      on (a.factset_inst_entity_id = b.factset_entity_id); *all have a parent;

/*updated 2025-02-26: add fund, entity, parent iso*/

/*match with fund id*/
proc sql;
      create table fswork.funds as select a.*, b.entity_proper_name as fund_name, b.iso_country as fund_iso

      from fswork.funds a left join factset.edm_standard_entity b

      on a.factset_fund_id = b.factset_entity_id

WHERE a.factset_fund_id is not null; 



 /*match with entity id, using managing company's domicile as fund location*/
proc sql;
      create table fswork.funds as select a.*, b.entity_proper_name as entity_name, b.iso_country as entity_iso

      from fswork.funds a left join factset.edm_standard_entity b

      on a.factset_inst_entity_id = b.factset_entity_id; 

 
proc sql;
      create table fswork.funds as select a.*, b.entity_proper_name as parent_name, b.iso_country as parent_iso

      from fswork.funds a left join factset.edm_standard_entity b

      on a.fs_ultimate_parent_entity_id = b.factset_entity_id; 
quit;


/*Augment with ticker and fsym_id*/
proc sql;
create table fswork.funds as select a.*, b.fund_ticker, b.fund_identifier as fsym_id

from fswork.funds a left join factset.own_ent_fund_identifiers b

on a.factset_fund_id=b.factset_fund_id;


/*Augment with other fund info from wrds_securities*/

/*Updated 2025-02-20: use FactSet symbolic tables not wrds securities*/
/*Security name and security information*/

proc sql;
create table fswork.funds as 
select a.factset_fund_id, a.factset_inst_entity_id, fund_name, 
d.proper_name as security_name, fund_family, entity_name, parent_name, fund_type, style, 
 etf_type, a.active_flag, fs_ultimate_parent_entity_id, 
  fund_iso, entity_iso, parent_iso,  fund_ticker, a.fsym_id,  
 d.currency,  d.universe_type, c.cusip, b.isin, e.sedol
/* d.fref_listing_exchange,*/
/*f.fref_exchange_location_code as excountry,*/
from fswork.funds a 
left join factset.sym_isin b on a.fsym_id=b.fsym_id
left join factset.sym_cusip c on a.fsym_id=c.fsym_id
left join factset.sym_coverage d on a.fsym_id=d.fsym_id
left join factset.sym_sedol e on e.fsym_id=d.fsym_regional_id;
/*left join factset.fref_sec_exchange_map f on d.fref_listing_exchange=f.fref_exchange_code*/
/*order by factset_fund_id;*/

proc sort data=fswork.funds nodupkey; by factset_fund_id fsym_id;  run;

proc sql; 
create table 
funds_fsym_ids as 
select factset_fund_id, count(*) as n 
from fswork.funds 
group by factset_fund_id
order by calculated n desc;

proc sql; 
create table test as 
select a.*, b.n 
from fswork.funds a, funds_fsym_ids b 
where a.factset_fund_id=b.factset_fund_id
and b.n>1
order by n desc;

/*proc sql; select count(*) from fswork.funds where fref_listing_exchange is not null;*/

/*proc sql; */
/*create table test as select * from factset.sym_coverage*/
/*where fsym_id in (select fsym_id from fswork.funds)*/
/*and fref_listing_exchange is not null;*/

/*proc sql; */
/*create table test_wrds as select * from factset.wrds_securities_v3*/
/*where fsym_id in (select fsym_id from fswork.funds)*/
/*and fref_listing_exchange is not null;*/

/*Conclusion: no funds have exchange information in factset*/

/*proc sql; select count(*) as n */
/*from factset.wrds_securities_v3 */
/*where excountry is not null */
/*and fsym_id in (select fsym_id from fswork.funds);*/
/**/
/*proc sql; select count(*) as n */
/*from factset.wrds_securities_v3 */
/*where fref_listing_exchange is not null*/
/*and fsym_id in (select fsym_id from fswork.funds);*/




proc sql;
create table test as select * from fswork.funds where excountry is not null;

proc sql;
create table fund_identifier_distribution as
select sum(cusip is not null) as n_cusip,
sum(isin is not null) as n_isin,
sum(sedol is not null) as n_sedol,
sum(fund_ticker is not null) as n_ticker, iso
from fswork.funds
where iso is not null
group by iso
order by calculated n_isin desc;

/*distribution of fund identifiers*/
proc sql;
create table wrds_fund_identifiers_dist as 
select a.iso, sum(b.cusip is not null) as n_cusip_wrds, sum(a.cusip is not null) as n_cusip,
sum(b.isin is not null) as n_isin_wrds, sum(a.isin is not null) as n_isin,
sum(b.sedol is not null) as n_sedol_wrds, sum(a.sedol is not null) as n_sedol,
sum(b.tic is not null) as n_tic, sum(a.fund_ticker is not null) as n_ticker
from fswork.funds a,  factset.wrds_securities_v3 b 
where a.fsym_id=b.fsym_id; 

/*Few instances these two are different*/
proc sql; 
select count(*) 
from fswork.funds 
where factset_Entity_id ne factset_inst_entity_id;


proc sort data=fswork.funds nodupkey; by factset_fund_id; run;

proc export data= fswork.funds
    outfile= 'S:\DFSWORK\factset_funds.csv'
    replace;run;



/*get useful entity information from edm_standard_entity*/
proc sql;
create table fswork.factset_entities as 
select factset_entity_id, entity_proper_name, iso_country, 
entity_type, entity_sub_type 
from factset.edm_standard_entity;

proc export data= fswork.factset_entities
    outfile= 'S:\FSWORK\factset_entities.csv'
    replace;run;


/*Security and entity identifiers*/

proc sql;
create table sym_identifiers1 as
select distinct fsym_ID from fswork.own_basic;

proc sql;
create table fswork.sym_identifiers as
select a.fsym_ID,
	   case
	      when b.isin is missing then c.isin
		  else b.isin
	   end as isin,
	   d.cusip,
	   f.sedol,
	   g.ticker_region,
	   c1.factset_entity_id,
	   c1.entity_proper_name
from sym_identifiers1 a 
left join factset.sym_isin b
		on (a.fsym_ID eq b.fsym_ID)
left join factset.sym_xc_isin c
		on (a.fsym_ID eq c.fsym_ID)
left join factset.sym_cusip d
		on (a.fsym_ID eq d.fsym_ID)
left join factset.sym_coverage e
		on (a.fsym_ID eq e.fsym_ID)
left join factset.sym_sedol f
		on (e.fsym_primary_listing_id eq f.fsym_ID)
left join factset.sym_ticker_region g
		on (e.fsym_primary_listing_id eq g.fsym_ID),
		factset.own_sec_entity_eq b1, factset.edm_standard_entity c1
where a.fsym_id=b1.fsym_id
and b1.factset_entity_id=c1.factset_entity_id
order by fsym_ID;


/*Firm-level identifiers*/
/*To be ran after Step2 firm-level ownership*/

* Fetch Principal Security;
proc sql;
create table fswork.principal_security as
select *
from factset.sym_coverage a
left join factset.own_sec_entity_eq b on a.fsym_id eq b.fsym_id
where b.factset_entity_id in (select distinct company_id from fswork.v2_holdingsall_firm)
and b.factset_entity_id is not missing
and a.fsym_id eq a.fsym_primary_equity_id
order by b.factset_entity_id;


* Remaining securities (Share & Prefeq);
proc sql;
create table fswork.remaining_securities as
select *
from factset.sym_coverage a
left join factset.own_sec_entity_eq b on a.fsym_id eq b.fsym_id
where b.factset_entity_id in (select distinct company_id from fswork.v2_holdingsall_firm)
and b.factset_entity_id not in (select factset_entity_id from fswork.principal_security)
and b.factset_entity_id is not missing
and a.fref_security_type in ('SHARE','PREFEQ')
order by b.factset_entity_id, a.active_flag desc, a.fref_security_type desc;


proc sql;
create table security_entity1 as
select factset_entity_id, fsym_id from fswork.principal_security
union all
select factset_entity_id, fsym_id from fswork.remaining_securities;

proc sql;
create table security_entity as
select a.*, b.fsym_primary_listing_id
from security_entity1 a
left join factset.sym_coverage b on a.fsym_id eq b.fsym_id;

proc sql;
create table fswork.entity_identifiers as
select a.*, 
	   case
	      when b.isin is missing then c.isin
		  else b.isin
	   end as isin, 
	   d.cusip,
	   e.sedol,
	   f.ticker_region
from security_entity a
left join factset.sym_isin b on a.fsym_id eq b.fsym_id
left join factset.sym_xc_isin c on a.fsym_id eq c.fsym_id
left join factset.sym_cusip d on a.fsym_id eq d.fsym_id
left join factset.sym_sedol e on a.fsym_primary_listing_id eq e.fsym_id
left join factset.sym_ticker_region f on a.fsym_primary_listing_id eq f.fsym_id;
