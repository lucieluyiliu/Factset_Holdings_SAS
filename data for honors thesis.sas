/*Ownership data for honors*/

proc sql;
create table us_security_ownership as 
select factset_entity_id, fsym_id, quarter, inst_country,  entity_sub_type, io
from fswork.v2_holdingsall_sec
where sec_country='US'
and entity_sub_type in ('PF','SV');

proc export data=us_security_ownership
outfile= "D:/Dropbox/Honors thesis Hayden/data/us_security_ownership.csv"
replace;run;

proc export data=inst_type
outfile= "D:/Dropbox/Honors thesis Hayden/data/inst_type.csv"
replace;run;


proc export data=fswork.sym_identifiers
outfile= "D:/Dropbox/Honors thesis Hayden/data/sym_identifiers.csv"
replace;run;
