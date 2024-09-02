/*Ownership at the institution and firm level*/

/*This script calcualtes security-level and firm-level ownership by institution-security*/


/*#0. Preamble: include auxiliary tables*/
* creates dual listed companies, institutional type tables, the list of countries to be considered (MSCI ACWI + Luxembourg (LU));
options dlcreatedir;
libname factset ('S:/factset/own_v5','S:/factset/common');
libname fswork 'S:/FSWORK/';
libname sasuser '~/sasuser.v94';
%include 'D:/factset_holdings/auxiliaries2024.sas';
%include 'D:/factset_holdings/functions.sas';
%let exportfolder=D:/jmp/; 


/*#1. Security-level ownership*/

proc sql;
create table v3_holdingsall as
select t1.fsym_id,
t1.company_id, 
t1.quarter, t1.factset_entity_id,
t1.sec_country, 
t1.inst_country,
		case
		  when t1.sec_country eq t1.inst_country then 1
		   else 0
		end as is_dom length=3,
		isglobal,
		case /*indicator for domestic country fund domiciled in security country focusing on security country*/
		  when iscountry=1 and t1.sec_country=t2.sec_country and t1.sec_country = t1.inst_country then 1 
		  else 0
		end as is_ctry length=3,
		t1.io  /*already adjusted*/
/* 	t1.dollarholding as dollarholding */
from  fswork.v2_holdingsall_sec t1, 
fswork.inst_isglobal t2
where 
t1.quarter eq t2.quarter 
and t1.factset_entity_id=t2.factset_entity_id
order by t1.fsym_id, t1.quarter, io desc;
quit;

proc sort data=v3_holdingsall nodupkey; by fsym_id quarter factset_entity_id;run;

proc sql;
create table fswork.holdings_by_security1 as
select 	a.fsym_id,
        a.company_id,  
		a.quarter,
		intnx('month',yyq(int(a.quarter/100),mod(a.quarter,100)),2,'end') format=MMDDYY10. as quarterdate,
		sec_country,
		count(*) as nbr_firms,
		sum(io) as io, 
	 	sum(io*is_dom) as io_dom,
		sum(io*(1-is_dom)) as io_for,
		sum(io*isglobal) as io_global,
		sum(io*is_ctry) as io_ctry, /*domestic country fund that focus on the security country*/
		own_mktcap
		
from v3_holdingsall a, fswork.sec_mktcap b 
where a.fsym_id=b.fsym_id
and a.quarter=b.quarter
group by a.fsym_id,company_id, a.quarter, sec_country,own_mktcap;
quit;

proc sql;
create table fswork.holdings_by_securities as 
select a.*
from fswork.holdings_by_security1 a, factset.edm_standard_entity b, ctry c
where a.company_id=b.factset_entity_id
and a.sec_country=c.iso
and b.primary_sic_code ne '6798'
and a.company_id is not null
and b.primary_sic_code is not null;


/*#2. Firm-level ownership by insstitution origin and type*/

proc sql;
create table v3_holdingsall as
select  t1.company_id, t1.quarter, t1.factset_entity_id, t1.sec_country, t1.inst_country, 
		case
		   when t1.sec_country eq t1.inst_country then 1
		   else 0
		end as is_dom length=3,
		case
		   when t1.inst_country eq 'US' then 1
		   else 0
		end as is_us_inst length=3, 
		case
		   when t1.inst_origin eq 'North America' then 1
		   else 0
		end as is_na_inst length=3, 
		case
		   when t1.inst_origin eq 'Europe' then 1
		   else 0
		end as is_eu_inst length=3, 	    
		case
		   when t1.inst_origin eq 'Others' then 1
		   else 0
		end as is_others_inst length=3, 
		case 
		   when cat_institution=1 then 1
		   else 0
		end as is_br length=3,
		case 
		   when cat_institution=2 then 1
		   else 0
		end as is_pb length=3,
		case 
		   when cat_institution=3 then 1
		   else 0
		end as is_hf length=3,
		case 
		   when cat_institution=4 then 1
		   else 0
		end as is_ia length=3,
		case 
		   when cat_institution=5 then 1
		   else 0
		end as is_lt length=3,

		t1.io_unadj,
		t1.adjf,
		t1.io
		
		
from fswork.v2_holdingsall_firm t1
order by t1.company_id, t1.quarter, io desc;

proc sql; select distinct inst_origin from fswork.v2_holdingsall_firm;


/*Aggregate at the firm-level*/

proc sql;
create table fswork.holdings_by_firm1 as
select 	company_id,  
		quarter,
		sec_country,
		count(*) as nbr_firms,
		/*FM aggregation*/
		/*dometsic io*/
		sum(io) as io,
		sum(io*is_dom) as io_dom,
		sum(io*(1-is_dom)) as io_for,
		
        /*us*/
        sum(io*is_us_inst) as io_us,
        sum(io*is_us_inst*(1-is_dom)) as io_for_us,

		/*na*/
        sum(io*is_na_inst) as io_na,
        sum(io*is_na_inst*(1-is_dom)) as io_for_na,
		
		
		/*eu*/
		sum(io*is_eu_inst) as io_eu,
		sum(io*is_eu_inst*(1-is_dom)) as io_for_eu,
		
	    /*foreign others*/
		sum(io*is_others_inst) as io_others,
		sum(io*is_others_inst*(1-is_dom)) as io_for_others,
		
		/*broker*/
		sum(io*is_br) as io_br,
		
	    /*private banking*/
		sum(io*is_pb) as io_pb,
		
		/*hedge fund*/
		sum(io*is_hf) as io_hf,
		
		/*investment advisor*/
        sum(io*is_ia) as io_ia,

		/*Long-term investor*/
        sum(io*is_lt) as io_lt
       

from v3_holdingsall
group by company_id, quarter, sec_country;




/*merge mktcap*/

proc sql stimer;
create table fswork.holdings_by_firm2 as
select  a.*, c.entity_proper_name,
		b.mktcap_usd as mktcap
from fswork.holdings_by_firm1 a, fswork.hmktcap b, factset.edm_standard_entity c
where b.eoq eq 1 and a.company_id eq b.factset_entity_id 
and a.quarter eq b.quarter and a.company_id eq c.factset_entity_id;

proc sql;
create table fswork.holdings_by_firm_all (drop=company_id) as
select  a.company_id as factset_entity_id, a.quarter, intnx('month',yyq(int(quarter/100),mod(quarter,100)),2,'end') format=MMDDYY10. as rquarter, a.sec_country, a.entity_proper_name, a.*
from fswork.holdings_by_firm2 a
where a.company_id not in (select factset_entity_id from factset.edm_standard_entity where primary_sic_code eq '6798')
order by a.company_id, a.quarter;

proc sql;
create table fswork.holdings_by_firm_ftse as
select b.* from fswork.ctry a, fswork.holdings_by_firm_all b 
where a.iso eq b.sec_country;

/*Annual firm-level ownership*/
proc sql;
create table fswork.holdings_by_firm_annual as 
select 
a.*,
case when iso='US' then 'US' else b.isem end as market,
int(quarter/100) as year, max(quarter) as maxqtr 
from fswork.holdings_by_firm_ftse a, fswork.ctry b
where a.sec_country=b.iso
group by factset_entity_id,calculated year, calculated market
having quarter=calculated maxqtr;
quit;

