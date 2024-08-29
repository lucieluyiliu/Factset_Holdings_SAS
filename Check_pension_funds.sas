/*Check pension funds in US and Australia*/

/*Institution pension fund*/
proc sql;
create table inst_pensionfunds as 
select a.*, b.quarter, b.aum
from home.factset_entities a, home.inst_aum b 
where iso_country in ('US','AU')
and a.factset_entity_id=b.factset_entity_id
and entity_sub_type='PF'
order by quarter, iso_country, aum desc;

proc export data=inst_pensionfunds
outfile= "D:/inst_pensionfunds.csv"
replace;run;

proc sql;
create table inst_pensionfunds_list as 
select *
from home.factset_entities 
where iso_country in ('US','AU')
and entity_sub_type='PF';

proc export data=inst_pensionfunds_list
outfile= "D:/inst_pensionfunds_list.csv"
replace;run;

proc sql; select max(quarter) from home.inst_aum;

/*Fund pendion fund*/

proc sql;
create table home.fund_aum as 
select factset_fund_id, quarter, sum(dollarholding) as aum
from home.v1_holdingsmf
group by factset_fund_id, quarter;

proc sql;
create table fund_pensionfunds as 
select a.factset_fund_id, a.quarter, a.aum, b.*
from home.fund_aum a, home.funds b, factset.fund_type_map c
where a.factset_fund_id=b.factset_fund_id
and b.fund_type=c.fund_type_code
and b.fund_type in ('PEP','PLP')
and iso in ('US','AU')
order by quarter, iso, aum desc;

proc export data=fund_pensionfunds
outfile= "D:/fund_pensionfunds.csv"
replace;run;

proc sql;
create table fund_pensionfunds_list as 
select *
from home.funds
where fund_type in ('PEP','PLP')
and iso in ('US','AU');

proc export data=fund_pensionfunds_list
outfile= "D:/fund_pensionfunds_list.csv"
replace;run;
