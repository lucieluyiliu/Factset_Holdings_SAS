/*This script compiles fund information from FactSet and security identifiers*/
/*1. Funds and FactSet entity identifiers*/
/*2. Security identifiers, to be ran after Step1A*/

/*Author: Lucie Lu, lucie.lu@unimelb.edu.au*/
/*Based on sample code from David Schumacher*/

options dlcreatedir;

libname factset ('F:/factset/own_v5','F:/factset/common');

libname home 'D:\factset_work\';

libname sasuser '~/sasuser.v94';

%include 'D:\factset_holdings\auxiliaries2023.sas';



data home.funds;

      set factset.own_ent_funds (drop= PE_RATIO PB_RATIO DIVIDEND_YIELD SALES_GROWTH PRICE_MOMENTUM RELATIVE_STRENGTH BETA CURRENT_REPORT_DATE TURNOVER_LABEL);

run;

* merge in parent info, fund name,...;

proc sql;

      create table home.funds as select *, b.fs_ultimate_parent_entity_id

      from home.funds a left join factset.edm_standard_entity_structure b

      on a.factset_inst_entity_id = b.factset_entity_id; *all have a parent;


/*match with fund id*/
proc sql;
      create table home.funds as select a.*, b.entity_proper_name as fund_name

      from home.funds a left join factset.edm_standard_entity b

      on a.factset_fund_id = b.factset_entity_id

      WHERE a.factset_fund_id is not null; 



 /*match with entity id, using managing company's domicile as fund location*/
proc sql;
      create table home.funds as select a.*, b.entity_proper_name as entity_name, b.iso_country as iso

      from home.funds a left join factset.edm_standard_entity b

      on a.factset_entity_id = b.factset_entity_id; 

 
proc sql;
      create table home.funds as select a.*, b.entity_proper_name as parent_name

      from home.funds a left join factset.edm_standard_entity b

      on a.fs_ultimate_parent_entity_id = b.factset_entity_id; 
quit;


proc sort data=home.funds nodupkey; by factset_fund_id; run;

proc export data= home.funds
    outfile= 'D:\jmp\factset_funds.csv'
    replace;run;


/*get useful entity information from edm_standard_entity*/
proc sql;
create table home.factset_entities as 
select factset_entity_id, entity_proper_name, iso_country, 
entity_type, entity_sub_type 
from factset.edm_standard_entity;

proc export data= home.factset_entities
    outfile= 'D:\jmp\factset_entities.csv'
    replace;run;


/*Security and entity identifiers*/

proc sql;
create table sym_identifiers1 as
select distinct fsym_ID from home.own_basic;

proc sql;
create table home.sym_identifiers as
select a.fsym_ID,
	   case
	      when b.isin is missing then c.isin
		  else b.isin
	   end as isin,
	   d.cusip,
	   f.sedol,
	   g.ticker_region,
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
